CentOS 6.7 + redmine 3.2 + jenkins + git + svn on docker
====

Redmie環境全部入りのイメージです。

## Description

### URL

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
>         - REDMINE_HOST=localhost:10180
>
> # add user if you want
> #        - USER=jozuko2
> #        - USER_PASSWORD=jozuko2
> #        - ROOT_PASSWORD=rootpw
>
> # redmine smtp settngs
>         - SMTP_ENABLE=n
> #       - SMTP_METHOD=smtp
> #       - SMTP_STARTTLS=true
> #       - SMTP_HOST=smtp.gmail.com
> #       - SMTP_PORT=587
> #       - SMTP_DOMAIN=smtp.gmail.com
> #       - SMTP_AUTHENTICATION=plain
> #       - SMTP_USER=user.name@gmail.com
> #       - SMTP_PASS=gmail-password
>
> #    restart: always

image: 変更しないでください。

ports: SSHの22ポートと、Redmineの80ポートをホストOSのポートに割り当てます。
       上記の記載だと、http://<host-address>:10180/でredmineが起動します。

volumes: redmineとmysqlのデータを保存するホストのディレクトリを指定します。
         上記の記載だと、以下のようになります。
         | 保存されるファイル               | ホストディレクトリのパス |
         |:---------------------------------|:-----------------------------------------------------------------|
         | Redmineのattachmentファイル      | <docker-compose.ymlがあるディレクトリ>/volumes/files/            |
         | Redmineの情報を含むMySQLのデータ | <docker-compose.ymlがあるディレクトリ>/volumes/mysql/            |
         | git / svnリポジトリデータ        | <docker-compose.ymlがあるディレクトリ>/volumes/repos/            |


## Install

## Contribution

## Licence

[MIT](https://github.com/tcnksm/tool/blob/master/LICENCE)

## Author

[tcnksm](https://github.com/tcnksm)