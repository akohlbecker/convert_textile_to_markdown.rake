# Taken from  http://stackoverflow.com/questions/9782121/how-to-convert-existing-redmine-wiki-from-textile-to-markdown
# see also http://www.redmine.org/issues/22005
# Modified to be compatible with newer Pandoc versions with "markdown_strict" format

require 'tempfile'

namespace :redmine do
  desc 'Syntax conversion from textile to markdown'
  task :convert_textile_to_markdown => :environment do

    module MarkdownConverter

      def self.convert

        puts 'NOTE: Make sure you are using a recent version of pandoc.'
        puts '      Otherwise the resulting markdown might be broken.'
        # pandoc 1.12.2.1 is not suitable

        who = "Converting wiki contents"
        wiki_content_count = 0
        wiki_content_total = WikiContent.count
        WikiContent.all.each do |wiki|
          wiki_content_count += 1
          simplebar(who + "(page_id: " + wiki.page_id.to_s + ")", wiki_content_count, wiki_content_total)
          ([wiki] + wiki.versions).each do |version|
            markdown = textile_to_md(version.text)
            version.update_attribute(:text, markdown)
          end
        end

        who = "Converting Issues"
        issue_count = 0
        issue_total = Issue.count
        Issue.all.each do |issue|
          issue_count += 1
          simplebar(who + "(id: " + issue.id.to_s + ")", issue_count, issue_total)
          markdown =  textile_to_md(issue.description)
          issue.update_attribute(:description, markdown)
        end

        who = "Converting Jounals"
        journal_count = 0
        journal_total = Journal.count
        Journal.all.each do |journal|
          journal_count += 1
          simplebar(who + "(id: " + journal.id.to_s + ")", journal_count, journal_total)
          markdown =  textile_to_md(journal.notes)
          journal.update_attribute(:notes, markdown)
        end

      end

      def self.textile_to_md(textile)
        src = Tempfile.new('textile')
        src.write(textile)
        src.close
        dst = Tempfile.new('markdown')
        dst.close

        command = [
            "pandoc",
            # "--no-wrap", # deprecated since v1.16 replaces by --wrap=none
            "--wrap=none", #
            "--smart",
            "-f",
            "textile",
            "-t",
            "markdown_strict", # alternatives: http://pandoc.org/README.html#markdown-variants
            "--atx-headers",
            src.path,
            "-o",
            dst.path,
        ]
        # print command
        system(*command) or raise "pandoc failed"

        dst.open
        markdown = dst.read

        # remove the \ pandoc puts before * and > at begining of lines
        markdown.gsub!(/^((\\[*>])+)/) { $1.gsub("\\", "") }

        # add a blank line before lists
        markdown.gsub!(/^([^*].*)\n\*/, "\\1\n\n*")

        # remove <!-- --> which occur between some list items, see pandoc manual 'Ending a list'
        markdown.gsub!(/^<!-- -->\n/, '')

        markdown
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
