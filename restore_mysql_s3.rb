#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'fileutils'
require 'mysql2'
require 'find'
require 'time'
require 'pit'
require 'aws/s3'
include AWS::S3

## get config from pit
Config = Pit.get('restore_config',
  :require => {
    'mysql' => {
      'host'       => 'mysql server',
      'user'       => 'mysql user',
      'pass'       => 'mysql password',
      'restore_db' => ['backup_db1', 'backup_db2'],
      'mysql_cmd'  => '/usr/bin/mysql',
    },
    'aws' => {
      'access_key_id'     => 'your AWS access key id',
      'secret_access_key' => 'your AWS secret access key',
      'bucket'            => 'your bucket name',
      'region'            => 'your aws region',
    },
    'local' => {
      'restore_dir'  => '/var/tmp/restore',
    },
  })

AWS::S3::Base.establish_connection!(
    :access_key_id     => Config['aws']['access_key_id'],
    :secret_access_key => Config['aws']['secret_access_key']
  )
AWS::S3::DEFAULT_HOST.replace Config['aws']['region']

def show_s3
  objects = Bucket.objects(Config['aws']['bucket'])
  dirs  = []
  files = []
  objects.each do |v|
    dir = File.dirname v.key
    dirs.push dir unless dirs.include?dir
    files.push v.key
  end
  latest = dirs.sort!.pop
  files.grep(/#{Regexp.escape latest}/)
end

def download(files)
  restore_files = []
  files.each do |file|
    base = File.basename file
    base =~ /^(.+)\.dump\.gz$/
    dst = "#{Config['local']['restore_dir']}/#{file}"

    ## restore対象かチェック
    next unless Config['mysql']['restore_db'].include?($1)

    ## localに保存済みは無視
    restore_files.push dst
    next if File.exists?dst

    ## write local from s3
    FileUtils.mkdir_p File.dirname dst
    open("#{dst}", 'w') do |v|
      S3Object.stream(file, Config['aws']['bucket']) do |chunk|
        v.write chunk
      end
    end
  end
  restore_files
end

def restore(files)
  files.each do |file|
    base = File.basename file
    base =~ /^(.+)\.dump\.gz$/
    db   = $1
    cmd = []
    cmd.push("zcat #{file}")
    cmd.push("|")
    cmd.push(Config['mysql']['mysql_cmd'])
    cmd.push("-u#{Config['mysql']['user']}")
    cmd.push("-p#{Config['mysql']['pass']}")
    cmd.push("-h#{Config['mysql']['host']}")
    cmd.push(db)
    system cmd.join(' ')
  end
end

def clean(files)
  files.each do |file|
    File.unlink file
  end
end

def main
  s3    = show_s3
  files = download(s3)
  restore(files)
  clean(files)
end

# run
main
