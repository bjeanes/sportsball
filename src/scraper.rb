require 'rubygems'
require 'mechanize'
require 'json'
require 'active_support/inflector/transliterate'
require 'active_support/inflector/methods'
require 'fileutils'
require 'date'
require 'set'

include ActiveSupport::Inflector

$main_content_xpath = "/html/body/table/tr[2]/td/table/tr[1]/td[4]"

data_dir = File.expand_path("../../resources", __FILE__)
corpus   = File.join(data_dir, "corpus")
men      = Set.new(File.readlines(File.join(data_dir, "men.txt")).map   { |n| parameterize(n) })
women    = Set.new(File.readlines(File.join(data_dir, "women.txt")).map { |n| parameterize(n) })

australian_open = 'http://www.asapsports.com/show_events.php?category=7&year=2013&title=AUSTRALIAN+OPEN'

def links_in_main_region(agent, page)
  main_content_area = page.at($main_content_xpath)
  main_content_area.search("a[@href]").map { |node| Mechanize::Page::Link.new(node, agent, page) }
end

agent = Mechanize.new
agent.get(australian_open) do |page|
  day_links = links_in_main_region(agent, page)

  day_links.each do |day_link|
    agent.transact do
      day_page = agent.click day_link

      sport = titleize day_page.at($main_content_xpath + "/h1").text.gsub(/[\u00A0\s\t\r\n]/, ' ').strip
      year = titleize day_page.at($main_content_xpath + "/h2").text
      event_and_date = day_page.at($main_content_xpath + "/h3").text
      _, event, date = event_and_date.match(/^\s*(.+)\s*\[\s*([^\]]+)\s*\]/).to_a
      event = titleize(event.gsub(/[\u00A0\s\t\r\n]/, ' ')).strip

      interview_links = links_in_main_region(agent, day_page)

      interview_links.each do |interview_link|
        agent.transact do
          interview_page = agent.click(interview_link)

          content = interview_page.at($main_content_xpath)
          raw_text = content.text
          interview = content.xpath("b | text()").select do |node|
            text = node.text.gsub(/^[\r\n\s]+|[\r\n\s]+$/, '')
            text != ''
          end

          qanda = interview.
            slice_before { |node| node.name == "b" }.
            map { |nodes|
              next if nodes.size == 1 || nodes.nil?

              person = nodes[1].text.match(/^[\r\n\s]+([A-Z -]+):/)[1] rescue nil
              question = nodes.first.text.
                gsub(/\u00A0/, ''). #nbsp
                gsub(/[^[:print:]]/, '').strip.
                gsub(/^[\r\n\s\t]*(THE MODERATOR|Q(uestion)?)[:.][\r\n\s\t]*/i, '').
                gsub(/[\r\n\s\t]+/, ' ').
                gsub(/^ | $/, '')
              answer = nodes.drop(1).
                map(&:text).
                reduce(&:+).
                gsub(/\u00A0/, ''). #nbsp
                gsub(/[^[:print:]]/, '').strip.
                gsub("#{person}:", '').
                gsub(/[\r\n\s\t]+/, ' ').
                gsub(/^ | $/, '')

              if person.nil?
                # debug
                p nodes[1].text
                next
              end

              {
                question: question,
                answer: answer,
                person: titleize(person)
              }
            }.compact

          people = interview_page.search("//h3/a").map(&:text)

          date = Date.parse("#{date}, #{year}").to_time.strftime("%Y-%m-%d")
          file = [sport, event, *date.split('-'), people.join(", ")].map { |c| parameterize(c) }.join("/")
          file = File.join(corpus, "sports", "#{file}.json")

          people.map! do |name|
            {
              name: name,
              gender: case
                when men.include?(parameterize(name)) then
                  "male"
                when women.include?(parameterize(name)) then
                  "female"
                else
                  "unknown"
              end
            }
          end

          FileUtils.mkdir_p(File.dirname(file))

          File.open(file, 'w') do |f|
            puts "Writing #{file}"
            f.write JSON.dump({
              sport: sport,
              event: event,
              date: date,
              people: people,
              text: raw_text,
              interview: qanda
            })
          end
        end
      end
    end
  end
end
