CentOS 6.7 + redmine 3.2 + jenkins + git + svn on docker
====

Redmie環境全部入りのイメージです。でもまだメンテナンス中です。DockerのAutoBuildがfailします...。（2016/02/29完成目標）  
This is an all-in-one image of Redmine.  

## Many thanks.

このイメージを作るきっかけとなったalminiumの作成者の方々、データの初期展開方法を載せてくださっているayapapaさん、その他先達の方々皆様に感謝です。  
People of the creator of alminium became a chance to make this image, ayapapa that who put the initial deployment method of data, the people everyone of other predecessors, I am very grateful.  
  
[alminium](https://github.com/alminium/alminium)  
[ayapapaさん docker-alminium](https://hub.docker.com/r/ayapapa/docker-alminium/)  


## Description

### アクセスURL - Access URL

Redmine：http://<host-address>:<port>/  
Jenkins：http://<host-address>:<port>/jenkins/  
git    ：http://<host-address>:<port>/git/  
svn    ：http://<host-address>:<port>/svn/  

### Redmieプラグイン一覧 - List of Plugins for Redmine

| Plugin                         | Description                                                                                                                         |
|:-------------------------------|:------------------------------------------------------------------------------------------------------------------------------------|
| redmine_xls_export             | チケットをExcelにエクスポート <br> Export a ticket to Excel                                                                         |
| redmine_plugin_views_revisions | redmine_xls_exportに必要なplugin <br> plugin necessary to redmine_xls_export                                                        |
| redmine_code_review            | リポジトリのdiffに対してコメントを書ける <br> Plug-in to write a comment to the repository of the diff                              |
| advanced_roadmap               | ロードマップを表示するプラグイン <br> Plug-in to view the road map                                                                  |
| scm-creator                    | Redmine上でリモートリポジトリを作成するプラグイン <br> Plug-in to create a remote repository on Redmine                             |
| redmine_drafts                 | 作成中のチケットを保存 <br> Save the ticket being created                                                                           |
| clipboard_image_paste          | チケットにイメージをコピペできる <br> You can copy and paste the image to the ticket                                                |
| redmine_banner                 | Redmineサイト上部に管理者からのメッセージを表示できる <br> You can display a message from the administrator to the Redmine site top |

## Demo

## インストールと使い方 - Install & Usage

docker-compose.ymlを作りましたので、それを元に使い方を説明します。  
Since I made a docker-compose.yml, it describes how to use based on it.  
  
1. Redmineのコンテナを作成するディレクトリで、https://github.com/jozuko/redmine-docker.git をcloneします。  
   In the directory in which you want to create a Redmine of container, https: the //github.com/jozuko/redmine-docker.git to "clone".  
> git clone https://github.com/jozuko/redmine-docker.git

2. redmine-dockerにdocker-compose.ymlが含まれていますので、自分の環境に合わせて編集します。  
   Since it contains a docker-compose.yml to redmine-docker, and edit it to suit your environment.  
> redmine:
>     image: jozuko/redmine-docker:redmine3.2
>
>     ports:
>         - "10122:22"
>         - "10180:80"
>
>     volumes:
>         - "./volumes/files/:/opt/redmine/files/"
>         - "./volumes/mysql/:/var/lib/mysql/"
>         - "./volumes/repos/:/var/opt/redmine/"
>
>     environment:
>         - USER=jozuko
>         - USER_PASSWORD=jozuko
>         - ROOT_PASSWORD=rootpw
>
>         - LOCALTIME=Japan
>         - TIMEZONE=Asia/Tokyo
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

**image:**  
　　変更しないでください。  
　　Please do not change.  

**ports:**  
　　22ポート(SSH)と80ポート(Redmine)をホストOSのポートに割り当てます。  
　　上記の記載だと、http://<host-address>:10180/でredmineが起動します。  
　　Assign the 22 port (SSH) and 80 port (Redmine) to a port on the host OS.  
　　That's the above description, "http://<host-address>:10180/" redmine will start in.  

**volumes:**  
　　redmineとmysqlのデータを保存するホストのディレクトリを指定します。  
　　上記の記載だと、以下のようになります。  
　　Specify the redmine and mysql directory of the host where you want to save the data.  
　　That's the above description, is as follows.  

| Contents                                                                           | The path of the host directory                                                                                      |
|:-----------------------------------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------|
| Redmineのattachmentファイル <br> Redmine attachments file                          | <docker-compose.ymlがあるディレクトリ>/volumes/files/ <br> <Directory there is a docker-compose.yml>/volumes/files/ |
| Redmineの情報を含むMySQLのデータ <br> MySQL data, including Redmine of information | <docker-compose.ymlがあるディレクトリ>/volumes/mysql/ <br> <Directory there is a docker-compose.yml>/volumes/mysql/ |
| git / svnリポジトリデータ <br> git / svn repository data                           | <docker-compose.ymlがあるディレクトリ>/volumes/repos/ <br> <Directory there is a docker-compose.yml>/volumes/repos/ |

**environment:**  
　　実行環境に合わせた設定を行います。使用しないkeyは、valueをブランクにしてください。  
　　Redmineのメール設定は、http://redmine.jp/faq/general/mail_notification/ を参照してください。  
　　Configure the settings to match the execution environment. key is not used, please refer to the value in the blank.  
　　Redmine e-mail settings, http: Please refer to the http://redmine.jp/faq/general/mail_notification/ .  

| Category | key                 | value                                                                                                                                                                                                                                                                                   |
|:---------|:--------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| OS       | USER                | 追加したいユーザがいる場合ユーザIDを指定します。                                                                               <br> If you have that you want to add a user to specify the user ID.                                                                                     |
| OS       | USER_PASSWORD       | 上記ユーザのパスワードを指定します。                                                                                           <br> It specifies the password of the USER.                                                                                                              |
| OS       | ROOT_PASSWORD       | rootのパスワードを指定します。デフォルトは rootpw です。                                                                       <br> Specify the root password. The default is rootpw.                                                                                                   |
| TimeZone | LOCALTIME           | /etc/localtimeにコピーするlocaltimeを指定します。/usr/share/zoneinfo/以下のディレクトリを指定してください。日本ならJapanです。 <br> It specifies the localtime to copy it to /etc/localtime. Please specify the directory under the "/usr/share/zoneinfo/". If London is Europe/London. |
| TimeZone | TIMEZONE            | タイムゾーンを指定します。日本ならAsia/Tokyo、ロンドンならEurope/Londonです。                                                  <br> Specify the time zone. If London is Europe/London.                                                                                                  |
| Redmine  | REDMINE_HOST        | 管理 > 設定 > 全般 の「ホスト名とパス」を指定します。メールを送信する際に、メール本文に記載されます。                          <br> Management> Settings> Specifies the "host name and path" General. When you send an e-mail, it will be included in the email body.                   |
| Redmine  | SMTP_ENABLE         | Redmineからメールを送信する場合は、 y を指定してください。                                                                     <br> If you want to send mail from Redmine, please specify the y.                                                                                        |
| Redmine  | SMTP_METHOD         | Redmineからメールを送信する場合は、 smtp を指定してください。                                                                  <br> If you want to send mail from Redmine, please specify the smtp.                                                                                     |
| Redmine  | SMTP_STARTTLS       | SMTPがTLSを使用する場合は、trueを指定してください。                                                                            <br> If SMTP is using TLS, please specify the true.                                                                                                      |
| Redmine  | SMTP_HOST           | SMTPのホストアドレスを指定してください。                                                                                       <br> Please specify the SMTP host address.                                                                                                               |
| Redmine  | SMTP_PORT           | SMTPのポート番号を指定してください。                                                                                           <br> Please specify the SMTP port number.                                                                                                                |
| Redmine  | SMTP_DOMAIN         | SMTPのドメインを指定してください。                                                                                             <br> Please specify the SMTP domain.                                                                                                                     |
| Redmine  | SMTP_AUTHENTICATION | SMTPの認証方式を指定してください。                                                                                             <br> Please specify the SMTP authentication method.                                                                                                      |
| Redmine  | SMTP_USER           | SMTPの認証ユーザを指定してください。                                                                                           <br> Please specify the SMTP authentication user.                                                                                                        |
| Redmine  | SMTP_PASS           | SMTPの認証パスワードを指定してください。                                                                                       <br> Please specify the SMTP authentication password.                                                                                                    |


**restart:**  
　　dockerサービス起動時に自動でリスターとさせる場合、alwaysを指定します。  
　　不要な場合は削除してください。  
　　If you want to with the Lister automatically to docker service starts, you can use the always.  
　　Please delete if not required.  


## Licence

https://github.com/jozuko/redmine-docker/blob/master/LICENSE

