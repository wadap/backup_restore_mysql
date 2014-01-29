backup restore mysql
==========

## 初期設定
awsの認証情報を保持するために、pitを仕様しています。以下のようにすれば設定ができるようになります。

```
export $EDITOR=vi
ruby ./backup_mysql.rb
```