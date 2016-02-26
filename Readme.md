CentOS 6.7 + redmine 3.2 + jenkins + git + svn on docker
====

Redmie環境全部入りのイメージです。でもまだメンテナンス中です。（2016/02/29完成目標）

## Description

### アクセスURL

Redmine：http://<host-address>:<指定ポート>/

Jenkins：http://<host-address>:<指定ポート>/jenkins/

git    ：http://<host-address>:<指定ポート>/git/

svn    ：http://<host-address>:<指定ポート>/svn/

### Redmieプラグイン一覧

| プラグイン                     | 概要                                                             |
|:-------------------------------|:-----------------------------------------------------------------|
| redmine_xls_export             | チケットをExcelにエクスポート                                    |
| redmine_plugin_views_revisions | redmine_xls_exportに必要なplugin                                 |
| redmine_code_review            | リポジトリのdiffに対してコメントを書けるコードレビュープラグイン |
| advanced_roadmap               | ロードマップを表示するプラグイン                                 |
| scm-creator                    | Redmine上でリモートリポジトリを作成するプラグイン                |
| redmine_drafts                 | 作成中のチケットを保存                                           |
| clipboard_image_paste          | チケットにイメージをコピペできる                                 |
| redmine_banner                 | Redmineサイト上部に管理者からのメッセージを表示できる            |

## Demo

## Usage

docker-compose.ymlを作りましたので、それを元に使い方を説明します。

1. Redmineのコンテナを作成するディレクトリで、https://github.com/jozuko/redmine-docker.git をcloneします。
> git clone https://github.com/jozuko/redmine-docker.git

2. redmine-dockerにdocker-compose.ymlが含まれていますので、自分の環境に合わせて編集します。

> redmine:
>     image: jozuko/redmine-docker:redmine3.2
>
>     ports:
>         - "10022:22"
>         - "10180:80"
>
>     volumes:
>         - "./volumes/files/:/opt/redmine/files/"
>         - "./volumes/mysql/:/var/lib/mysql/"
>         - "./volumes/repos/:/var/opt/redmine/"
>
>     environment:
>         - USER=jozuko2
>         - USER_PASSWORD=jozuko2
>         - ROOT_PASSWORD=rootpw
>
>         - REDMINE_HOST=localhost:10180
>
>         - SMTP_ENABLE=n
>         - SMTP_METHOD=smtp
>         - SMTP_STARTTLS=true
>         - SMTP_HOST=smtp.gmail.com
>         - SMTP_PORT=587
>         - SMTP_DOMAIN=smtp.gmail.com
>         - SMTP_AUTHENTICATION=plain
>         - SMTP_USER=user.name@gmail.com
>         - SMTP_PASS=gmail-password
>
>     restart: always

image: 変更しないでください。

ports: SSHの22ポートと、Redmineの80ポートをホストOSのポートに割り当てます。
       上記の記載だと、http://<host-address>:10180/でredmineが起動します。

volumes: redmineとmysqlのデータを保存するホストのディレクトリを指定します。
         上記の記載だと、以下のようになります。

| 保存されるファイル               | ホストディレクトリのパス                                         |
|:---------------------------------|:-----------------------------------------------------------------|
| Redmineのattachmentファイル      | <docker-compose.ymlがあるディレクトリ>/volumes/files/            |
| Redmineの情報を含むMySQLのデータ | <docker-compose.ymlがあるディレクトリ>/volumes/mysql/            |
| git / svnリポジトリデータ        | <docker-compose.ymlがあるディレクトリ>/volumes/repos/            |

environment:実行環境に合わせた設定を行います。使用しない環境変数は'keyごと削除'してください。

メール設定の詳細は、http://redmine.jp/faq/general/mail_notification/ を参照してください。


| key                 | value                                                                                                          |
|:--------------------|:---------------------------------------------------------------------------------------------------------------|
| USER                | 追加したいユーザがいる場合ユーザIDを指定します。                                                               |
| USER_PASSWORD       | 上記ユーザのパスワードを指定します。                                                                           |
| ROOT_PASSWORD       | rootのパスワードを指定します。デフォルトは rootpw です。                                                       |
| REDMINE_HOST        | Redmineの管理 > 設定 > 全般 の「ホスト名とパス」を指定します。メールを送信する際に、メール本文に記載されます。 |
| SMTP_ENABLE         | Redmineがメールを送信する場合は、 y を指定してください。                                                       |
| SMTP_METHOD         | Redmineがメールを送信する場合は、 smtp を指定してください。                                                    |
| SMTP_STARTTLS       | SMTPがTLSを使用する場合は、trueを指定し、使用しない場合は、keyごと削除してください。                           |
| SMTP_HOST           | SMTPのホストアドレスを指定してください。                                                                       |
| SMTP_PORT           | SMTPのポート番号を指定してください。                                                                           |
| SMTP_DOMAIN         | SMTPのドメインを指定してください。                                                                             |
| SMTP_AUTHENTICATION | SMTPの認証方式を指定してください。                                                                             |
| SMTP_USER           | SMTPの認証ユーザを指定してください。                                                                           |
| SMTP_PASS           | SMTPの認証パスワードを指定してください。                                                                       |


restart: dockerサービス起動時に自動でリスターとさせる場合、alwaysを指定します。

## Contribution


## Licence



## Author

