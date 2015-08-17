---
layout: default
title: Include Component Plugin Documentation
---

# Include Component Plugin Documentation

1. [Getting started](#gettingstarted)
2. [Configuration parameters](#configparams)
3. [Redirect to the origin](#redirecttoorigin)
4. [Troubleshooting](#troubleshooting)
    1. [Template styling](#templatestyling)

## <a name="gettingstarted">Getting started</a>

1. Create the article or component that you want to embed.
![First step]({{ site.url }}/images/inst_usage_step1.jpg)
2. Create a new menu item, but don't link any module to it. It may be of the type "show a single article", or a component, like, for instance, the VirtueMart category layout. The plugin will take its output regardless it's an article or a component.
![Second step]({{ site.url }}/images/inst_usage_step2.jpg)
3. Following the syntax in the image, embed the URL of the menu item where you want. The content will be automatically embedded, as if it was in the original component.
![Third step]({{ site.url }}/images/inst_usage_step3.jpg)
4. If you're embedding an article, you might want to tweak it a bit so that the title and other details won't appear.

## <a name="configparams">Configuration parameters</a>

The plugin include component has the following paremeters to be used at the command:

 
<table>
<tbody>
<tr>
<td>Name</td>
<td>Values</td>
<td>Default</td>
<td>Description</td>
</tr>
<tr>
<td>url</td>
<td> </td>
<td> </td>
<td class="desc">
<p>The url to the component.</p>
<p>Replace with the url to your component and include <code>index.php?</code><br /> For example:<br /><code>url='index.php?option=com_component&amp;Itemid=73&amp;parameters....'</code><br /> <br /> You maybe need to change the url when using an SEF component. If you get a component not found when using normal url then use the SEF url. So not:<br /><code>index.php?option=com_contact&amp;lang=en&amp;view=category</code><br />but:<br /><code>Contact-Us/category/</code><br /><br /> You can make a hidden menu item so you can configure components with their menu paramaters. You should add the menu id as a parmeter to the url for the plugin, for example:<br /><code>index.php?option=com_contact&amp;lang=en&amp;view=category&amp;Itemid=63</code></p>
</td>
</tr>
</tbody>
</table>

The plugin also has parameters in the configuration screen. Goto menu extensions, submenu plugin manager, search the plugin and click on the name.
There you have the following parameters:

<table>
<tbody>
<tr>
<td>Name</td>
<td>Values</td>
<td>Default</td>
<td>Description</td>
</tr>
<tr>
<td>Ignore scripts</td>
<td> </td>
<td> </td>
<td class="desc">
<p>Add here the scripts that have to be ignored. Enter each relative url on a new line.</p>
<p>Add the standard javascripts loaded by the template in the ignore fields of the plugin. <br />This should be the same url as in the generated source of the page or the file index.php in the template directory.<br />Every url on a new line.</p>
<p>So for example:<br /><code>/templates/rt_replicant2_j15/js/rokmoomenu.js</code><br /><code>/templates/rt_replicant2_j15/js/rokfonts.js</code></p>
</td>
</tr>
<tr>
<td>Ignore stylesheets</td>
<td> </td>
<td> </td>
<td class="desc">
<p>Add here the stylesheets that have to be ignored. Enter each relative url on a new line.</p>
<p>Add the standard stylesheets loaded by the template in the ignore fields of the plugin. <br />This should be the same url as in the generated source of the page or the file index.php in the template directory.<br />Every url on a new line.</p>
So for example:<br /><code>/templates/rt_versatility_iii_j15/css/template.css</code><br /><code>/templates/rt_versatility_iii_j15/css/style15.css</code></td>
</tr>
<tr>
<td>Method</td>
<td class="desc">
  <ul>
    <li>file_get_contents</li>
    <li>curl</li>
  </ul>
</td>
<td>file_get_contents</td>
<td class="desc">
<p>You can choose <code>file_get_contents</code> or <code>curl</code>. Curl has the best results, but requires the curl library installed at the PHP webserver.</p>
<p>Curl also has the ability to login and support http security and php authentication.</p>
</td>
</tr>
<tr>
<td>Close session</td>
<td>
<p>Yes<br />No</p>
</td>
<td>No</td>
<td class="desc">
<p>Close the session in Joomla to pass it to other component.<br />If a session is not closed the called component may not work correctly in retrieving session parameters.<br />(Experts only)</p>
</td>
</tr>
<tr>
<td>CB Token replace</td>
<td>Yes<br />No</td>
<td>No</td>
<td class="desc">Replace the tokens that CB generated with new tokens based on the page where CB is included.</td>
</tr>
<tr>
<td>Remove print</td>
<td>Yes<br />No</td>
<td>Yes</td>
<td class="desc">Remove the print parameter in all links on the page (default) so links goto pages with template css include instead of only print.css.</td>
</tr>
<tr>
<td>Remove tmpl</td>
<td>Yes<br /> No</td>
<td>Yes</td>
<td class="desc">Remove the tmpl parameter in all links on the page (default) so links goto pages with full layout (header/modules) instead of only the component output.</td>
</tr>
<tr>
<td>Run as Admin</td>
<td>
<p>Yes<br />No</p>
</td>
<td>No</td>
<td class="desc">USE WITH EXTREME CAUTION. Run the plugin in administrator of Joomla too. Only set this to yes if you know the plugin works in the frontend correctly and do it first on a test domain where you also have FTP access or database to recover access to the administrator!</td>
</tr>
<tr>
<td>Caching</td>
<td>Yes<br />No</td>
<td>No</td>
<td class="desc">Use caching and override the general Joomla setting. If caching is enabled in Joomla it will use caching even if this parameter is set to off.</td>
</tr>
</tbody>
</table>

## <a name="redirecttoorigin">Redirect to the origin</a>

The include plugin adds the origin of the refer page to the url for the component. This way the component knows what page called the article where the component is included.

In the component you can capture this origin and use it for a redirection. For example:


    if( this->error() ) {
        $origin = base64_decode( JRequest::getVar( 'origin' ) );
        // clean origin up a bit to grab only the path & query
        $origin = JUri::getPath( $origin ).'?'.JUri::getQuery( $origin );
        $this->setRedirect( $origin );
    }


Thanks to Hugo Jackson.

## <a name="troubleshooting">Troubleshooting</a>

In some cases the plugin does not run and does not show the contents of the component or the contents is not looking the same as when the component is called standalone.
When the plugin does not show contents of the included component, look into the generated source of the page and search for the comments of the plugin include component. There may be shown errors and give your tips on how to solve it.
You also can use Firebug to look into the generated source and to check if the correct css is used.

The plugin can not work because of the following causes:

1. The plugin opens a connection to the same webserver where the script is running from. These types of 'loopback' connections are sometimes blocked on shared hosting for server safety.
2. Ask your hosting company for help.
3. The plugin opens a url so the webserver must resolve the url to an ip-address and needs to use a DNS server. So the DNS has to be configured on the webserver or the host file on the webserver should redirect it to the localhost.
4. If the design of the page is wrong, you must check if css files are loaded multiple times. You can try to ignore the css file that is loaded twice and you can try to ignore the print.css file. For print.css check what the correct url is in the generated source of the page.

### <a name="templatestyling">Template styling</a>

If you include a component then the styling can be different then when you call it directly. This is caused by the loading of the css files in the template and plugin.
The plugin loads the stylesheets and javascripts to make sure the component gets the correct styling and behavior.

The plugin gets the components page and looks for stylesheets (<link> and <style>) and javascripts (<script>) in the head of the components page. If it finds a style or script then it extracts it out of the header and add it thru the Joomla Framework to the caling page.
If a template load it's stylesheets and javascript not thru the Joomla Framework then you can get duplicates that can influence your styling or behavior.

You can solve this in two ways:

1. Edit the template:
   - Load the javascript files at the beginning of the file index.php in the template directory with:

            $doc =& JFactory::getDocument();
            $doc->addScript("http://www.example.com/js/myscript.js");

   - Load the stylesheet files at the beginning of the file index.php in the template directory with:

            $doc =& JFactory::getDocument();
            $doc->addStyleSheet( 'http://www.example.com/css/mystylesheet.css' );

2. Add the standard javascripts and stylesheets loaded by the template in the ignore fields of the plugin (version => 1.9). This should be the same as in the generated source of the page or the file index.php in the template directory.

The first solution should be the standard development rule for Joomla Templates.

Another option in Joomla 1.6, 1.7 and 2.5 is to add to the url `?template=atomic` or if there are other parameters in the url `&template=atomic`.
This can help with complex template frameworks like for example Gantry.

