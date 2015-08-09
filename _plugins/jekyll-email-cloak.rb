require_relative "jekyll-email-cloak/version"
require 'securerandom'

module JekyllEmailCloak
  class CloakEmailTag < Liquid::Tag
    def render(context)
      if args = determine_arguments(@markup.strip)
        cloak_tag(args)
      else
      raise ArgumentError.new <<-eos
      Syntax error in tag 'cloak_email' while parsing the following markup:
        #{@markup}
      Valid syntax examples:
        {% cloak_email ryan binarydreamer.com %}
        {% cloak_email ryan binarydreamer.com 'Click Here' %}
        {% cloak_email ryan binarydreamer.com same_as_email some_class1 some_class2 %}
      eos
      end
    end
   
    private
     
    def determine_arguments(input)
      matched = input.scan(/([^\s"']+|"([^"]*)"|'([^']*)')/).map { |item| clean_arg(item[0]) }
      matched if matched && matched.length >= 2
    end
   
    def cloak_tag(args)
      args[2] = '' if args[2] == 'same_as_email'
      link_id = "cloak_email_#{SecureRandom.uuid.gsub("-", "").hex}"
      <<-eos
        <a href="#" id="#{link_id}" class="cloak-email #{args[3..-1].join(' ') if args[4]}" data-before="#{args[0]}" data-after="#{args[1]}">#{args[2]}</a>
        <script type="text/javascript"> var cloak = function() { el = document.getElementById("#{link_id}"); var after = el.dataset.after; var before = el.dataset.before; el.href = 'mailto:' + before + '@' + after; if(el.innerHTML == '') { el.innerHTML = before + '@' + after; } }(); </script>
      eos
    end

    def clean_arg(arg)
      arg.strip.gsub(/\A'|"/, '').gsub(/'|"\Z/, '')
    end
  end
end

Liquid::Template.register_tag('cloak_email', JekyllEmailCloak::CloakEmailTag)
