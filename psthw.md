---
layout: default
title: Problem-solving the hard way.
---

# Problem-solving the hard way: why system logs don't get into kern.log

#### Although sometimes port-knocking has been tagged as an odd technique for die-hard paranoids that does not worth the effort, I personally find it useful. An elegant and cheap way of fine-graining your control. Back when I was setting up Moxie Marlinspike's knockknockd portknocking daemon in my new server, I noticed that `kern.log` was always empty. What's more, no one of the kernel messages was being logged, neither in `kern.log` nor anywhere. This was a problem, since knockknockd heavily relies in `kern.log`. We'll have a close look at why was this happening.

### Revision history


| Initial publish | 22 Jan, 2015 |
| Migration to Jekyll. Revision. | 26 Aug, 2015 |

### Solution

My setup at the time was Ubuntu 12.04 LTS + sysklogd 1.5, which came pre-installed as the syslog daemon by default. Just in case you've ended up here in a deliberate midnight attempt to fix that issue, we'll start by summing up the solution:

    # service klogd start

That's it. Now you'll be able to sleep peacefully.

### Dissecting the sysklogd system log daemon

It turns out that sysklogd was designed in the most obvious way. If you get the [source code](https://launchpad.net/ubuntu/+source/sysklogd) and compile it (I'm not talking about the official source, but the Ubuntu fork), you'll get two executables: `syslogd` and `klogd`. Why did I say it is so intuitively designed? Because actually, there are two kinds of system logs: the ones that come from userspace (think of MySQL logs, for instance), and the ones that come from the kernel (think of `iptables`). And although they both follow the same guidelines, they're stored in different places, and so they must be retrieved in different ways. Having said that, you can now imagine what each of those programs does. The former retrieves the userspace logs (and acts as a server for remote syslogs) and the latter gets to the kernel logs. More specifically, `klogd` actually acts as a syslog client: it reads the kernel logs from the kernel ring buffer, and forwards them to `syslog` via the same mechanism as the other userspace programs. The problem is that when the system boots, only `sysklogd` is started. One would probably expect that both daemons are automatically run, and that's why `kern.log` is always empty, because the daemon responsible for getting the kernel logs, `klogd`, is not started at boot. That explains the solution: `klogd` must be manually started each time the system starts in order to get the kernel logs. I was unable to reproduce this behavior in other systems, so I'm unsure whether I should consider it a bug in the `sysklogd` init scripts. Maybe my hosting company shipped a pre-configured server that for some reason disabled `klogd`, but anyway.

So, I've decided to turn this article into a brief walkthrough through the syslog architecture, the userspace and kernel logs, and the `init` process and its runlevels. In the following sections, I'll talk about how `syslogd` and `klogd` work, and I'll end up explaining how one could make `klogd` start automatically at boot time, as well as any other service.

#### How syslogd works

The `syslogd` daemon features various sources to get the system logs from. Those are specified at compile time via preprocessor constants. I'll mention two of them, which, in my opinion, are the most relevant to this article: `SYSLOG_INET` and `SYSLOG_UNIXAF`. The first one enables syslog to listen through an `AF_INET` socket (think of the typical sockets we all learnt about in our networking lessons :D) and the second one does the same with `AF_UNIX` sockets, bound by default to the `/dev/log` file. It is bound to that file because the syslog(3) system call bounds to that file too. When it listens through an inet socket, it bounds to the default syslog port over UDP, which is 514, if not otherwise indicated.

`syslogd` is started by default with the arguments `-u syslog`, which means that it will run under the user "syslog".

Now, let's see it in code. Things are set up in the `init()` method. If `SYSLOG_UNIXAF` was set when compiling (`-DSYSLOG_UNIXAF`, which is set by default in the Makefile), it first creates all the necessary UNIX sockets:

    #ifdef SYSLOG_UNIXAF
        for (i = 0; i < nfunix; i++) {
            if (funix[i] != -1)
                /* Don't close the socket, preserve it instead
                close(funix[i]);
                */
                continue;
            if ((funix[i] = create_unix_socket(funixn[i])) != -1)
                dprintf("Opened UNIX socket `%s'.\n", funixn[i]);
        }
    #endif

`funixn` is an array of strings containing the names of the files that have to be checked for logs. By default it only has one element, `/dev/log`, but more elements can be added with the `-a` switch, which, for some reason was not specified in the usage. The `-p` switch specifies what they call "the regular log socket", that is, the first element of the `funixn` array, that as I said defaults to `/dev/log`.

UNIX sockets are different from the traditional network sockets in that they are created with the `AF_UNIX` flag and that they're bound to files instead of ports (they can also be anonymous). They're used in the Unix world for efficient interprocess communication, similar to the Windows named pipes. The `create_unix_socket()` function above creates one of those and bounds it to the filename passed as an argument:

    static int create_unix_socket(const char *path) {

        struct sockaddr_un sunx;

        // ...

        sunx.sun_family = AF_UNIX;
        (void) strncpy(sunx.sun_path, path, sizeof(sunx.sun_path));
        fd = socket(AF_UNIX, SOCK_DGRAM, 0);

        // ...

    }

If `SYSLOG_INET` is set, the same process is repeated with the internet sockets we all know. In this case though, only one socket is created.

Then, the file descriptors of all the created sockets are put into the `readfds` fd set for reading and polled in an infinite loop with select(2).

    #ifdef SYSLOG_UNIXAF
            /*
             * Add the Unix Domain Sockets to the list of read
             * descriptors.
             */
            /* Copy master connections */
            for (i = 0; i < nfunix; i++) {
                if (funix[i] != -1) {
                    FD_SET(funix[i], &readfds);
                    if (funix[i]>maxfds) maxfds = funix[i];
                }
            }
    #endif

    #ifdef SYSLOG_INET
            /*
             * Add the Internet Domain Socket to the list of read
             * descriptors.
             */
            if ( InetInuse && AcceptRemote ) {
                FD_SET(inetm, &readfds);
                if (inetm>maxfds) maxfds = inetm;
                dprintf("Listening on syslog UDP port.\n");
            }
    #endif

To sum up, log entries are read from many sources at the same time. We have all the UNIX sockets in the first place, and by default `/dev/log`. Every process can bound a UNIX socket to that file and write to it, and the bytes written will be read by `syslogd`. Then we have the INET socket listening on UDP 514. A process can also send datagrams there, and those will also be read by `syslogd` as long as they follow a particular format.

Every time some input is read it is decoded and written to the appropriate log files as specified in the syslog.conf(5) config file. When you call `syslog()`, you must give a priority and a facility (we'll dive into syslog(3) later). The priority indicates the log entry's importance, and the facility indicates who is generating that log entry. These priority-facility tuple that is attached to every log entry is then used by `syslogd` to classify the logs. For example, you might want to ignore the logs with INFO priority in order not to flood your log files, and put the ALERT level logs both in a file and on the console. The `syslogd` configuration is very rich and really lets you play a lot with it. `rsyslog`, a so-called "reliable" implementation, adds even more options. So far, the following priorities are available, in decreasing order of importance:

 - LOG_EMERG
 - LOG_ALERT
 - LOG_CRIT
 - LOG_ERR
 - LOG_WARNING
 - LOG_NOTICE
 - LOG_INFO
 - LOG_DEBUG

This explains why, by default, all LOG_EMERG messages are output to all the active consoles.

And these are the available facilities:

 - LOG_AUTH
 - LOG_AUTHPRIV
 - LOG_CRON
 - LOG_DAEMON
 - LOG_FTP
 - LOG_KERN
 - LOG_LPR
 - LOG_MAIL
 - LOG_NEWS
 - LOG_SYSLOG
 - LOG_USER
 - LOG_UUCP
 - LOG_LOCAL0 to 7

#### How klogd works


The `klogd` daemon acts as a bridge between the kernel ring buffer and the `syslogd` daemon. The kernel ring buffer is where the messages written via `printk()` by kernel modules get queued. `klogd` itself does not put these messages into the log files, but forwards them to the `syslogd` process running on the host just like any other process would. There are two distinct sources to read the kernel logs from, one can use the klogctl(2) system call, or tail the `/proc/kmsg` file. By default, `klogd` runs with the argument `-P /var/run/klogd/kmsg`, which tells him to do the second one, and yes, that path is the file it should read from. But, why isn't it `/proc/kmsg`? Well, the answer is that `klogd` is a bit lazy as we'll see later, and lets another program read `/proc/kmsg` for him.

If we have a lookup at `/etc/init.d/klogd`, the init script responsible for setting `klogd` up and running, we'll see, that it runs two programs simultaneously (I've replaced the variables with their actual values):

    start-stop-daemon --start --pidfile /var/run/klogd/kmsgpipe.pid --exec /bin/dd -b -m -- bs=1 if=/proc/kmsg of=/var/run/klogd/kmsg

    start-stop-daemon --start --quiet --chuid klog --exec /sbin/klogd -- "-P /var/run/klogd/kmsg"

That means, that it will run `dd` and `klogd` simultaneously, making `dd` read from `/proc/kmsg` and write to `/var/run/klogd/kmsg`, and then making `klogd` read from `/var/run/klogd/kmsg`, instead of from `/proc/kmsg`, which is the default. Why the init script sets up things this way is unknown to me, although it seems to be nothing but a matter of style.

Now, let's dissect `klogd`. First, if option `-P` has been specified, it sets its argument as the kernel log source (where to get the kernel logs from):

    case 'P':           /* Alternative kmsg file path */
        kmsg_file = strdup(optarg);
     break;

Then, if `kmsg_file` has been specified, it opens that file, otherwise, it initializes the kernel logging via klogctl(2).

    static enum LOGSRC GetKernelLogSrc(void)
    {

    // ...

    if ( kmsg_file ) {
                    if ( !strcmp(kmsg_file, "-") )
                            kmsg = fileno(stdin);
                    else {
                            if ( (kmsg = open(kmsg_file, O_RDONLY)) < 0 )
                            {
                                    fprintf(stderr, "klogd: Cannot open kmsg file, " \
                                            "%d - %s.\n", errno, strerror(errno));
                                    ksyslog(7, NULL, 0);
                                    exit(1);
                            }
                    }
                    return proc;
            }

    // ...

    // otherwise:

    if ( use_syscall ||
            ((stat(_PATH_KLOG, &sb) < 0) && (errno == ENOENT)) )
        {
              /* Initialize kernel logging. */
              ksyslog(1, NULL, 0);
    #ifdef DEBRELEASE
            Syslog(LOG_INFO, "klogd %s.%s#%s, log source = ksyslog "
                   "started.", VERSION, PATCHLEVEL, DEBRELEASE);
    #else
            Syslog(LOG_INFO, "klogd %s.%s, log source = ksyslog "
                   "started.", VERSION, PATCHLEVEL);
    #endif
            return(kernel);
        }

        // ...

    }

Once everything has been initialized, it enters the main loop, and, since the previous call to `GetKernelLogSrc()` returned the value `proc`, it will call `LogProcLine()` constantly until a signal is received. `LogProcLine()` will read 4096 bytes (default size for `log_buffer`), and then call `LogLine()` to actually forward those bytes to `syslogd`. If option `-s` was specified instead of `-P`, `GetKernelLogSrc()` would return the value `kernel`, and the `LogKernelLine()` function would be called, which would read 4096 bytes via klogctl(2), and then forward them the same way via `LogLine()`.

This is the main loop:

    while (1)
    {
        if ( change_state )
            ChangeLogging();
        switch ( logsrc )
        {
            case kernel:
                LogKernelLine();
                break;
            case proc:
                LogProcLine();
                break;
            case none:
                pause();
                break;
        }
    }

Then, `LogProcLine()` will read 4095 bytes from the file `/var/run/klogd/kmsg`:

    static void LogProcLine(void)
    {
        auto int rdcnt;

        memset(log_buffer, '\0', sizeof(log_buffer));
        if ( (rdcnt = read(kmsg, log_buffer, sizeof(log_buffer)-1)) < 0 )
        {
            if ( errno == EINTR )
                return;
            Syslog(LOG_ERR, "Cannot read proc file system: %d - %s.", \
                   errno, strerror(errno));
        }
        else
            LogLine(log_buffer, rdcnt);

        return;
    }

And finally, `LogLine()`, will send that data to `syslogd`. Behind the scenes, it just calls syslog(3). So it uses the same mechanisms as the other daemons to bring the kernel messages to userspace. Actually, it does this via the `Syslog()` function, which is nothing but a wrapper around syslog(3).

### iptables, syslog and printk

The linux kernel provides a function called `printk()`. As one might imagine, it's `printf()` but in the kernel. It's the most straightforward mechanism to debug kernel code as it happens to use the same syntax as the ANSI C `printf()` we all know. What's more, you'll find it funny to see that the source `printk()` documentation references `printf()`:

    /**
     * printk - print a kernel message
     * @fmt: format string
     *
     * This is printk().  It can be called from any context.  We want it to work.
     *
     * [...]
     *
     * See also:
     * printf(3)
     *
     * See the vsnprintf() documentation for format string extensions over C99.
     */

    asmlinkage int printk(const char *fmt, ...)

    {
        ...
    }

One must provide a logging priority when calling `printk()`, so `printk()` calls usually look like the following:

    printk(KERN_DEBUG "This is a debug message at %s:%i", __FILE__, __LINE__);

It looks like the traditional `printf()` function, but with a difference: like in `syslog()`, a priority must be appended. See that `KERN_DEBUG`? That's the priority. Actually, it's just a string whose value is "<7>":

    #define KERN_DEBUG    "<7>"

And the priority is compulsory: `printk()` expects something in the format "<X>" appended to the log string. There are no facilities here, only priorities. And they're similar to the `syslog()` ones:

    #define KERN_EMERG         "<0>"

    #define KERN_ALERT          "<1>"

    #define KERN_CRIT              "<2>"

    #define KERN_ERR               "<3>"

    #define KERN_WARNING    "<4>"

    #define KERN_NOTICE         "<5>"

    #define KERN_INFO               "<6>"

    #define KERN_DEBUG          "<7>"

    #define KERN_DEFAULT      "<d>"

    #define KERN_CONT             "<c>"

The tricky thing here is that `printk()` doesn't actually print stuff on the console as the traditional `printf()` does. It actually stores the messages in a circular buffer.

    for (; *p; p++) {
    
        ...
        
        emit_log_char(*p);
        
        if (*p == '\n')
            new_text_line = 1;
    }

Here, `p` is a pointer to the actual message being logged. The `emit_log_char()` function sends one character to the log buffer:

    static void emit_log_char(char c)
    {
        LOG_BUF(log_end) = c;
        log_end++;
        if (log_end - log_start > log_buf_len)
            log_start = log_end - log_buf_len;
        if (log_end - con_start > log_buf_len)
            con_start = log_end - log_buf_len;
        if (logged_chars < log_buf_len)
            logged_chars++;
    }

It's worth noting that, since the buffer is circular, and its size is limited, the oldest messages will be overwritten if the buffer gets full. And finally, this buffer is nothing but a character array of length `__LOG_BUF_LEN`:

    #define __LOG_BUF_LEN    (1 << CONFIG_LOG_BUF_SHIFT)
    ...
    #define LOG_BUF(idx) (log_buf[(idx) & LOG_BUF_MASK])
    ...
    static char __log_buf[__LOG_BUF_LEN];
    static char *log_buf = __log_buf;

This buffer lives in the kernel, so there must be a way of bringing those messages to userspace. This is where the `/proc/kmsg` file mentioned before comes in. This file is the interface between the kernel log buffer and the userspace applications. If you're interested, the code that handles all the I/O over `/proc/kmsg` is at `fs/proc/kmsg.h`. Another alternative is to call the `klogctl()` system call, but the former approach is usually easier. Reading from `/proc/kmsg` means reading the kernel log buffer. That's exactly what `klogd` does, through `dd`.

#### syslog(3)

Three functions are available in userspace to forward messages to the locally running `syslog` daemon. According to `man 3 syslog`:

    void openlog (const char *, int, int)
 - opens a connection with the locally running syslog daemon.
    void closelog ()
 - closes the connection with the locally running syslog daemon.
    void syslog (int priority, const char * format, ...)
 - sends a message to the locally running syslog daemon through a previously established connection. If no previous call to openlog() has been made, this is done automatically.

Now we'll finally understand why our syslog daemon opens a UNIX socket bound to `/dev/log`. Yes, `openlog()` does exactly that: it opens an `AF_UNIX` socket through `/dev/log` and writes al the messages there. The `syslog` daemon opens a socket through the same file, and reads from there. All these routines are implemented in glibc. For example, if you can write basic network code in C, the `openlog()` code will hardly surprise you:

    static struct sockaddr_un SyslogAddr;    /* AF_UNIX address of local logger */
    ...
    if (LogFile == -1) {
                SyslogAddr.sun_family = AF_UNIX;
                (void)strncpy(SyslogAddr.sun_path, _PATH_LOG,
                          sizeof(SyslogAddr.sun_path));
                
                if (LogStat & LOG_NDELAY) {
                    ...
                    LogFile = __socket(AF_UNIX, LogType, 0);
                    ...
                }
    }

Where `LogFile` is just an integer holding the socket file descriptor, and `_PATH_LOG` is, as you might have already guessed:

    #define    _PATH_LOG    "/dev/log"

Once the socket has been created, the last step is to establish the connection:

    ...
    __fcntl(LogFile, F_SETFD, FD_CLOEXEC);
    ...
    if (__connect(LogFile, &SyslogAddr, sizeof(SyslogAddr)) == -1)
    {
        int saved_errno = errno;
        int fd = LogFile;
        LogFile = -1;
        (void)__close(fd);
        __set_errno (old_errno);
        if (saved_errno == EPROTOTYPE)
        {
            /* retry with the other type: */
            LogType = (LogType == SOCK_DGRAM
                   ? SOCK_STREAM : SOCK_DGRAM);
            ++retry;
            continue;
        }
    } else
        connected = 1;

And finally, once the connection has been established, the `connected` flag is set to 1 and subsequent connections to `syslog` just have to write to the `LogFile` descriptor.

    if (!connected || __send(LogFile, buf, bufsize, send_flags) < 0)
      {
        if (connected)
          {
            /* Try to reopen the syslog connection.  Maybe it went
               down.  */
            closelog_internal ();
            openlog_internal(LogTag, LogStat | LOG_NDELAY, 0);
          }

        if (!connected || __send(LogFile, buf, bufsize, send_flags) < 0)
          {
            closelog_internal ();    /* attempt re-open next time */
            /*
             * Output the message to the console; don't worry
             * about blocking, if console blocks everything will.
             * Make sure the error reported is the one from the
             * syslogd failure.
             */
            if (LogStat & LOG_CONS &&
                (fd = __open(_PATH_CONSOLE, O_WRONLY|O_NOCTTY, 0)) >= 0)
              {
                dprintf (fd, "%s\r\n", buf + msgoff);
                (void)__close(fd);
              }
          }
      }

If for some reason the connection fails, the message is output to the console.

#### iptables

`iptables` features a target called LOG, that logs the packets thrown to it in the kernel. Actually, another target called ULOG exists, that forwards these logs directly to userspace via a netlink socket, but we'll not discuss that possibility here since an application has to create an `AF_NETLINK` socket in order to be able to read them, and Moxie Marlinspike's knockknockd doesn't do it. iptables-extensions(8) shows us its available configuration options:

    --log-level <level>

    --log-prefix <prefix>

    --log-tcp-sequence

    --log-tcp-options

    --log-ip-options

As of kernel version 3.2, the implementation of the LOG target can be found at `net/ipv4/netfilter/ipt_LOG.c` (I'm considering the IPv4 version here). We want to find the "entry point" of this target to understand how do these packets get logged, so we'll look at the `xt_target` structure, which is the one that contains the target's information:

    static struct xt_target log_tg_reg __read_mostly = {
        .name          = "LOG",
        .family        = NFPROTO_IPV4,
        .target        = log_tg,
        .targetsize    = sizeof(struct ipt_log_info),
        .checkentry    = log_tg_check,
        .me            = THIS_MODULE,
    };

We can imagine that the function `log_tg` is the one in charge of the actual logging. Packets are logged using the following format:

    Sep 17 20:53:45 myhost kernel: [4109709.373563] TESTIN=eth0 OUT= MAC= SRC=A.A.A.A DST=B.B.B.B LEN=100 TOS=0x00 PREC=0x00 TTL=48 ID=<ip identifier> DF PROTO=TCP SPT=<src port> DPT=<dst port> SEQ=<seq no> ACK=<ack no> WINDOW=<tcp window> RES=0x00 ACK PSH URGP=0

In order to manage the string that will be logged, it uses a simple dynamically increasing buffer called `sbuff`, defined in `xt_log.h`:

    struct sbuff {
        unsigned int    count;
        char        buf[S_SIZE + 1];
    };

It's nothing but a char array and its counter, as simple as that. Then, three methods are provided to manage those buffers: `sb_open()`, which allocates a new `sbuff` via `kmalloc()`, `sb_add()`, which is an `sprintf()`-style function that appends a string to the `sbuff` using the kernel-provided `vsnprintf()` behind the scenes, and finally `sb_close()`, which does the actual logging and frees the `sbuff`. The last one is actually where the magic is done. Yes, as you might imagine, it calls `printk()` to log the string.

    static void sb_close(struct sbuff * m) {
        m->buf[m->count] = 0;        // null-terminate the string, otherwise printk will jump past the buffer's boundaries
        printk("%s\n", m->buf);
        if (likely(m != &emergency)
            kfree(m);
        else {...}
    }

Provided those functions, the rest is easy:

    struct sbuff *m = sb_open();
    ...
    sb_add(m, "<%d>%sIN=%s OUT=%s ", loginfo->u.log.level,
               prefix,
               in ? in->name : "",
               out ? out->name : "");
    ...
    sb_close();

### Conclusions

So, we've seen that userspace applications can log messages with `syslog()`. They also can send the logs to a remote host via UDP, if there's a `syslog` daemon running and listening on the remote host. Kernel logs are kept in a circular buffer, and can be read from userspace by tailing `/proc/kmsg`. A part of `iptables` runs in the kernel. So, if the LOG target is active, all the packets that pass through it will be logged in the kernel. That's why it's imperative to have an efficient `syslogd` daemon running on the system if we don't want to lose packet logs. This means that if we're using `sysklogd`, the `klogd` daemon must be up and running.

### UNIX Runlevels Are Not /etc/init.d

Many people, and I include myself in the past, used to think that the `/etc/init.d` directory ruled the startup of the system's services, that is, that everything you threw into that directory was automatically run at system startup. Wrong! Take any program, put it there (or symlink it), reboot your system, and you'll see no difference. Actually, the program responsible for running the system's services at startup is the `init` program. Well, at least the default `init` program. Let's explain this starting from the very basics.

When Linux starts, it executes just a single program, usually called `init`. And that process, always with PID 0, starts all the other processes. So, all the processes that run in a Linux system are children of `init`. The code that runs `init` can be found in `init/main.c`, in the Linux source tree:

    static char *execute_command;
    ...
    static noinline int init_post(void)
    {
        ...
        if (execute_command) {
            run_init_process(execute_command);
            printk(KERN_WARNING "Failed to execute %s. Attempting defaults...\n", execute_command);
        }
        
        run_init_process("/sbin/init");
        run_init_process("/etc/init");
        run_init_process("/bin/init");
        run_init_process("/bin/sh");

        panic("No init found.  Try passing init= option to kernel. "
              "See Linux Documentation/init.txt for guidance.");

    }

So, it first tries to execute the path of `execute_command`. That variable is filled with the value of a kernel parameter called "init". If you don't specify that parameter, then `execute_command` will be empty, and it will try the defaults. If none of them is found, then the kernel panics. What does all this mean? It means that if you boot the kernel and pass the parameter `init=/bin/sh`, you'll end up with root privileges, and without having to know the password! That's because the kernel executes `/bin/sh` as the `init` program, and of course, the `init` program is always executed as root.

There are several implementations of the `init` process. Each Linux distribution uses its own. At the time of writing, Debian uses the *sysv-rc* implementation. Ubuntu uses *upstart*. If you're in Debian, you can get the source code of *sysv-rc* with the following command:

    # apt-get source sysv-rc

We've said that the `init` process is responsible for running all the other processes, and at this point you might have already discovered its relation with the automatic service startup. Of course, the `init` process is the one that starts all the services, but it doesn't look for them in the `/etc/init.d` directory, but in a series of directories under `/etc` whose names start with "rc". The `init` process splits the time in runlevels. During system startup, it transitions from one runlevel to other various times, and for each transition, it runs and stops some services. Let's have a look at one of those directories prefixed with "rc":

    /etc$ ls -l rc3.d
    <output trimmed>
    lrwxrwxrwx 1 root root  17 ago 20 19:16 S16rsyslog -> ../init.d/rsyslog
    <output trimmed>

We'll focus on a symlink called `S16rsyslog`. Actually, all the files in that directory are symlinks, and all of them have similar names: they're all prefixed with "S" and two digits. These are the files that are really executed at startup. Everything you put here, provided that it starts with "S", plus two digits, will be executed at system startup. Well, in the above example, it will be executed in runlevel 3, because the directory is called `rc3.d`. And, if it starts with "K" plus two digits, it will be stopped (I'll explain this later). The files in these directories are usually symlinks to scripts in `/etc/init.d`, because it's easier for a system administrator to modify those scripts instead of tweaking the runlevel files manually. What's more, these symlinks aren't even created by hand in most of the cases. They're automatically generated when installing a package with the `update-rc.d` command.

There are eight runlevels available, called, respectively 0, 1, 2, 3, 4, 5, 6 and S. According to the `sysv-rc` configuration file, `/etc/inittab`, they mean the following:

 - **Runlevel 0:** it's reached just before halting the system.
 - **Runlevel 1:** single-user environment.
 - **Runlevels 2-5:** multi-user environment.
 - **Runlevel 6:** reached just before rebooting the system.
 - **Runlevel S:** this is always the first runlevel executed when the system starts.

And, it also happen to be eight directories, one for each runlevel:

    /etc$ ls | awk '/^rc.*.d/ { print $0 }'
    rc0.d
    rc1.d
    rc2.d
    rc3.d
    rc4.d
    rc5.d
    rc6.d
    rcS.d

Everything you put in these directories will be executed when `init` switches to that runlevel, if it starts with "S" + two digits, and will be passed the argument "start". If it starts with "K" + two digits, it will be passed the argument "stop". That's why all the scripts in `/etc/init.d` respond to at least those two arguments, because they must perform meaningful actions when they're invoked by `init`.

### return 0

And it's over. We've had a brief walkthrough over the Linux logging system and we've seen some practical use cases, as well as common sources of trouble. Finally, we've had a quick overview of the Linux `init` process. I hope you enjoyed this article as much as I enjoyed writing it.

