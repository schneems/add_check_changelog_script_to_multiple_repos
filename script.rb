buildpacks = %W{
  heroku-buildpack-nodejs
  heroku-buildpack-go
  heroku-buildpack-python
  heroku-buildpack-php
  heroku-buildpack-scala
  heroku-buildpack-java
  heroku-buildpack-pgbouncer
  heroku-buildpack-google-chrome
  heroku-buildpack-chromedriver
  heroku-buildpack-xvfb-google-chrome
  heroku-buildpack-nginx
  heroku-buildpack-clojure
  heroku-buildpack-jvm-common
  heroku-buildpack-apt
  heroku-buildpack-emberjs
  heroku-buildpack-cli
  heroku-buildpack-elixir
  heroku-buildpack-static
  heroku-buildpack-python
}

def run(cmd)
  puts "Running: #{cmd}"
  out = `#{cmd}`
  raise out unless $?.success?
  out
end

Dir.chdir("buildpacks")
buildpacks.each do |pack|
  puts "== WORKING ON #{pack} =="

  url = "https://github.com/heroku/#{pack}"
  run("git clone #{url}") unless Dir.exist?(pack)

  Dir.chdir(pack) do
    run("git co -b schneems/check-changelog-fix-escaping")

    run("mkdir -p .github/workflows/")

    File.open(".github/workflows/check_changelog.yml", "w+") do |f|
      # Need to single quote this here doc otherwise the regex
      # gets escaped
      # https://stackoverflow.com/questions/29124058/string-literal-without-need-to-escape-backslash
      f.puts <<~'FILE'
        name: Check Changelog

        on: [pull_request]

        jobs:
         build:
           runs-on: ubuntu-latest
           steps:
           - uses: actions/checkout@v1
           - name: Check that CHANGELOG is touched
             run: |
               cat $GITHUB_EVENT_PATH | jq .pull_request.title |  grep -i '\[\(\(changelog skip\)\|\(ci skip\)\)\]' ||  git diff remotes/origin/${{ github.base_ref }} --name-only | grep CHANGELOG.md
      FILE
    end

    File.open("commit.msg", "w+") do |f|
      f.puts <<~FILE
        [changelog skip] Fix Escaping in Changelog Script

        The previous PR had a bug where the REGEX for grep was not properly escaped. This PR fixes that issue.
      FILE
    end
    run("git add .github/workflows/check_changelog.yml")
    run("git commit -F commit.msg")

    run("git push origin")
    run("hub pull-request master -F commit.msg -h heroku:schneems/check-changelog-fix-escaping")
  end
rescue => e
  puts "#{pack} failed #{e.message}"
end

