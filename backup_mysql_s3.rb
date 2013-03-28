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
Config = Pit.get('backup_config',
  :require => {
    'mysql' => {
      'host'      => 'mysql server',
      'user'      => 'mysql user',
      'pass'      => 'mysql password',
      'mysqldump' => '/usr/bin/mysqldump',
      'ignore_db' => ['mysql', 'test', 'information_schema', 'performance_schema'],
    },
    'local' => {
      'backup_dir'  => '/var/backup',
      'purge_limit' => 5,
    },
    'aws' => {
      'access_key_id'     => 'your AWS access key id',
      'secret_access_key' => 'your AWS secret access key',
      'bucket'            => 'your bucket name',
      'region'            => 'your aws region',
    },
  })

## Local Config
BackupFile = '%s.dump.gz';

## db一覧取得
def show_db
  dbs = []
  client = Mysql2::Client.new(
    :host     => Config['mysql']['host'],
    :username => Config['mysql']['user'],
    :password => Config['mysql']['pass']
  )
  client.query('SHOW DATABASES').each do |v|
    dbs.push(v['Database']) unless Config['mysql']['ignore_db'].include?(v['Database'])
  end
  dbs
end

## mysqldump
def mysqldump(dbs)
  date_path = Time.now.strftime('%Y/%m/%d/%H')
  dst = "#{Config['local']['backup_dir']}/#{date_path}"
  FileUtils.mkdir_p dst
  backup_files = []
  dbs.each do |db|
    cmd = []
    cmd.push(Config['mysql']['mysqldump'])
    cmd.push("-h#{Config['mysql']['host']}")
    cmd.push("-u#{Config['mysql']['user']}")
    cmd.push("-p#{Config['mysql']['pass']}")
    cmd.push(db)
    cmd.push("|")
    cmd.push("gzip")
    cmd.push(">")
    cmd.push("#{dst}/#{sprintf(BackupFile, db)}")
    system cmd.join(' ')
    backup_files.push "#{dst}/#{sprintf(BackupFile, db)}"
  end
  backup_files
end

## s3へput
def put_s3(files)
  AWS::S3::Base.establish_connection!(
    :access_key_id     => Config['aws']['access_key_id'],
    :secret_access_key => Config['aws']['secret_access_key']
  )
  AWS::S3::DEFAULT_HOST.replace Config['aws']['region']
  files.each do |file|
    path  = file.split(Config['local']['backup_dir'])
    path = path[1]
    if File.exists?(file)
      S3Object.store(
        path,
        open(file),
        Config['aws']['bucket']
      )
    end
  end
end

## ファイル削除
def purge
  Find.find(Config['local']['backup_dir']).each do |v|
    fs = File::Stat.new(v)
    if fs.file? then
      result = (Time.now - fs.mtime).divmod(24*60*60)
      File.unlink(v) if (result[0] > Config['local']['purge_limit'])
    end
  end
end

## main
def main
  dbs   = show_db
  files = mysqldump(dbs)
  put_s3(files)
  purge
end

## run
main
