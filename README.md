# shobo

foltiaの録画ファイル名をタイトル名に変えて参照リンク精製するやつ

cron で定間隔で回すとsamba みやすくなる

    \\192.168.x.x\mp4\アニメ\2017_1Q\うらら迷路帖\うらら迷路帖 #1 20170106-2330 26ch.MP4

みたいな感じであくせすできるようになる
  
 * https://github.com/katakk/tid が ポスグレ対応したポン *
 
 しょぼカルから採取したデーターはポスグレに飛ばすように変更
 
*getxml2db.pl* でポスグレにアニメタイトルは渡してるんだけど、カテゴリは渡していないみたいで、とりあえずlibwww-perl でしょぼカルdbに取りに行ってる。

~~アクセスしまくらないように dbはローカルに保持するんだけど、ときどき壊れる。~~

    
## samba

    [record]
    path = /record
  
    [record2]
    path = /record2
    
    [mp4]
    path = /mp4
    
    [raw]
    path = /raw
    
    [anime]
    path = /anime

## df

    Filesystem      Size  Used Avail Use% Mounted on
    /dev/sde2       6.8G  5.5G  975M  86% /
    tmpfs            16G     0   16G   0% /dev/shm
    /dev/sde1       310M   34M  261M  12% /boot
    tmpfs            16G  348K   16G   1% /tmp
    tmpfs            16G     0   16G   0% /raw
    tmpfs            16G     0   16G   0% /record
    tmpfs            16G     0   16G   0% /record2
    tmpfs            16G     0   16G   0% /anime
    tmpfs            16G     0   16G   0% /mp4
    /dev/md127       11T  9.1T  1.9T  84% /home/foltia/php/tv


## crontab -l

    5 5,8,9,10,17,20,22 * * * ionice -c 3 nice -n 19 /usr/bin/perl shobo_record2.pl
    8 5,8,9,10,17,20,22 * * * ionice -c 3 nice -n 19 /usr/bin/perl shobo_record.pl
    15 1,2,3,4,5,8,9,10,17,20,22,23 * * * ionice -c 3 nice -n 19 /usr/bin/perl shobo_mp4.pl
    25 5,8,9,10,17,20,22,23 * * * ionice -c 3 nice -n 19 /usr/bin/perl shobo_lnraw.pl
    28 5,8,9,10,17,20,22,23 * * * ionice -c 3 nice -n 19 /usr/bin/perl shobo_ani.pl

