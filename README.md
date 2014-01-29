backup restore mysql
==========

## 概要
mysqldumpをとって、S3へバックアップ/S3からリストアするscriptです。

## セットアップ

```
$ git clone git@github.com:wadap/backup_restore_mysql.git
$ bundle install --path vendor/bundle
```

## 初期設定
awsの認証情報を保持するために、pitを使用しています。以下のようにすればエディタが立ち上がるので設定してください。

```
$ export $EDITOR=vi
$ bundle exec backup_restore_mysql.rb
```