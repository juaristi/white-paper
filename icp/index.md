---
layout: default
title: Include Component Plugin
---

# Include Component Plugin

The Include Component Plugin is a plugin for Joomla that allows to embed an article or any other component inside another one, without the need of using iframes. It's as easy as creating an article, and then in another article, or category description put the following string:

```
{component url='<component_url>'}
```

You must replace `<component_url>` with the actual relative URL of the article or component that you want to insert. Then, its content will be embedded exactly where the string was found. Of course, you may put text and any other kind of content before and after that string.

The best way of using this plugin is by creating a new menu item pointing to an article or a component (the VirtueMart layout, for example), but without linking it to a menu module. That way the menu item will be active, but will not be shown. Then just copy the URL of the menu item, and insert it in another article following the above syntax. This is just an example, but there are other ways. You might also use the URL of the article/component itself. But the interesting thing in using a menu item is that the embedded component will receive the parameters of the menu item, and it could act consequently.

**I'm no longer working on this project due to lack of time and hence I don't give support for it. I'm sorry for the inconvenience this might have caused to you.** However, you can still find the documentation in this website.

[Include Component Plugin Documentation](doc.html)

[Sponsors](sponsors.html)

