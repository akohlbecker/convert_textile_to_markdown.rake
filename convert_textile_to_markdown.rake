# Taken from  http://stackoverflow.com/questions/9782121/how-to-convert-existing-redmine-wiki-from-textile-to-markdown
# see also http://www.redmine.org/issues/22005
# Modified to be compatible with newer Pandoc versions with "markdown_strict" format

require 'tempfile'

namespace :redmine do
  desc 'Syntax conversion from textile to markdown'
  task :convert_textile_to_markdown => :environment do

    module MarkdownConverter

      def self.convert

        wiki_content_count = 0

        who = "Converting wiki contents"
        wiki_content_total = WikiContent.count
        WikiContent.all.each do |wiki|
          wiki_content_count += 1
          print "page_id: " + wiki.page_id.to_s
          simplebar(who, wiki_content_count, wiki_content_total)
          ([wiki] + wiki.versions).each do |version|
            textile = version.text
            src = Tempfile.new('textile')
            src.write(textile)
            src.close
            dst = Tempfile.new('markdown')
            dst.close

            command = [
                "pandoc",
                "--no-wrap",
                "--smart",
                "-f",
                "textile",
                "-t",
                "markdown_strict",
                src.path,
                "-o",
                dst.path,
            ]
            system(*command) or raise "pandoc failed"

            dst.open
            markdown = dst.read

            # remove the \ pandoc puts before * and > at begining of lines
            markdown.gsub!(/^((\\[*>])+)/) { $1.gsub("\\", "") }

            # add a blank line before lists
            markdown.gsub!(/^([^*].*)\n\*/, "\\1\n\n*")

            version.update_attribute(:text, markdown)
          end
        end
      end


      old_notified_events = Setting.notified_events
      begin
        # Turn off email notifications temporarily
        Setting.notified_events = []
        # Run the conversion
        MarkdownConverter.convert
      ensure
        # Restore previous settings
        Setting.notified_events = old_notified_events
      end

    end

    # Simple progress bar
    def simplebar(title, current, total, out = STDOUT)
      def get_width
        default_width = 80
        begin
          tiocgwinsz = 0x5413
          data = [0, 0, 0, 0].pack("SSSS")
          if out.ioctl(tiocgwinsz, data) >= 0 then
            rows, cols, xpixels, ypixels = data.unpack("SSSS")
            if cols >= 0 then
              cols
            else
              default_width
            end
          else
            default_width
          end
        rescue Exception
          default_width
        end
      end

      mark = "*"
      title_width = 40
      max = get_width - title_width - 10
      format = "%-#{title_width}s [%-#{max}s] %3d%%  %s"
      bar = current * max / total
      percentage = bar * 100 / max
      current == total ? eol = "\n" : eol ="\r"
      printf(format, title, mark * bar, percentage, eol)
      out.flush
    end

  end
end
