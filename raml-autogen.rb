#!/usr/bin/env ruby

=begin
This script will monitor the current directory for changes to a RAML file and run the raml2html script to generate the corresponding HTML file, which is then kept refreshed in Safari in the background. Specify the input file on the command line like this: `./raml-autogen.rb MyApiSpec.raml`. By default, this script will output the HTML file with the same name and a .html extension; you can specify an alternate output filename as a second parameter on the command line if you would prefer.

When the directory watcher detects a change to the specified file, it will run the raml2html function to generate the human-readable output. Then an AppleScript is run that will check to see if that html file is already loaded in a Safari tab. If it is, it will reload it silently in the background. If it's not already loaded, it will open Safari and open the local html file in a new tab.

Every time a change is noticed, information will be output to the terminal window running the script. When you're done using the script, just hit `Enter` and the script will stop.
=end

require 'rubygems'
require 'directory_watcher'
require 'URI'

directory = '.'
infile = ARGV[0].to_s
outfile = (ARGV[1] || infile.gsub(".raml", ".html")).to_s
raise Exception.new("Usage: ./raml-autogen.rb infile.raml outfile.html") if infile == '' || outfile == ''

def reload_uri(local_filename)
  filepath = File.realpath local_filename
  file_url = "file://" + URI.encode(filepath).to_s
  
  osascript <<-END
    set fileUrl to "#{file_url}"
    set tabAlreadyLoaded to false
    if application "Safari" is running then
    	tell application "Safari"
    		repeat with aTab in (every tab of every window)
    			if URL of aTab is fileUrl then
    				set URL of aTab to fileUrl
    				set tabAlreadyLoaded to true
    			end if
    		end repeat
    	end tell
    end if
    if tabAlreadyLoaded is false then
    	do shell script "open " & fileUrl
    end if
  END
end

def osascript(script)
  system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
end


dw = DirectoryWatcher.new directory
dw.interval = 1.0
dw.add_observer do |*args|
  args.each do |event|
    if File.join(directory, infile) == event.path && event.type.to_s == 'modified'
      `raml2html -t resource-sif.nunjucks -i #{infile} -o #{outfile}`
      puts "#{Time.now.strftime("%I:%M:%S")} \
        Generated #{outfile} (since #{event.path} #{event.type})"
      reload_uri(outfile)
    end
  end
end

dw.start
puts "Watching '#{directory}' for changes. Will generate #{infile} => #{outfile}"
puts "Press enter to quit."
STDIN.gets  # when the user hits "enter" the script will terminate
dw.stop
