#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Carp;

use Sys::Syslog qw(:DEFAULT setlogsock);
use Storable qw/lock_nstore lock_retrieve/;
use File::Find;
use File::Path;
use Encode 'encode';
use LWP::Simple qw/get/;
use XML::Simple; #sudo yum install  expat-devel perl-XML-Simple
use Data::Dumper;
setlogsock 'unix';
openlog($0, 'pid', 'local0');
my $regex = '\.(m2t|MP4|aac)$';
my $dept = '/record/';
my $nomakedir = 0;
my $tv = '/home/foltia/php/tv/';
my $tiddb = 'tid.db';
my %tidarc = ();
my $tid = \%tidarc;
#my %cat = qw#
#    1   アニメ
#    10  アニメ完了
#    7   OVA
#    5   アニメ関連
#    4   特撮
#    8   映画
#    3   テレビ
#    2   ラジオ
#    6   メモ
#    0   その他
##;
my %cat = qw#
    1   アニメ
    10  アニメ
    7   アニメ
    5   アニメ
    4   特撮
    8   アニメ
    3   アニメ
    2   ラジオ
    6   アニメ
    0   その他
#;

$tid->{0}->{title} = 'unknown';
$tid->{0}->{cat} = 0;
sub tid_to_name
{
  my $number = shift;
  my $title;
  my $cat;
  return unless($number); #number=0 => TIDの指定が不正です
  return if(exists($tid->{$number}));
  sleep 1;
  my $config = XMLin(get(sprintf 
    qq|http://cal.syoboi.jp/db.php?Command=TitleLookup&TID=%d|,
     $number));
	$title = $config->{TitleItems}->{TitleItem}->{Title};
	# リネームできんかった
	$title =~ s/\//／/g if($title);
	$title =~ s/\:/：/g if($title);
	$title =~ s/\*/＊/g if($title);
	$title =~ s/\?/？/g if($title);
	$title =~ s/\"/”/g if($title);
	$title =~ s/\</＜/g if($title);
	$title =~ s/\>/＞/g if($title);
	$title =~ s/\|/｜/g if($title);
	$title =~ s/\"/”/g if($title);
	$title =~ s/\!/！/g if($title); 
	$title =~ s/\\/＼/g if($title);
	$title =~ s/♡/_/g  if($title); 
	$tid->{$number}->{title} = $title;
	$tid->{$number}->{cat} = $config->{TitleItems}->{TitleItem}->{Cat};
	$tid->{$number}->{FirstYear} = $config->{TitleItems}->{TitleItem}->{FirstYear};
	$tid->{$number}->{FirstMonth} = $config->{TitleItems}->{TitleItem}->{FirstMonth};
	$tid->{$number}->{FirstEndYear} = $config->{TitleItems}->{TitleItem}->{FirstEndYear};
	$tid->{$number}->{FirstEndMonth} = $config->{TitleItems}->{TitleItem}->{FirstEndMonth};
	$tid->{$number}->{UserPoint} = $config->{TitleItems}->{TitleItem}->{UserPoint};
	$tid->{$number}->{UserPointRank} = $config->{TitleItems}->{TitleItem}->{UserPointRank};
	$tid->{$number}->{TitleYomi} = $config->{TitleItems}->{TitleItem}->{TitleYomi};
syslog('info', "getting tid %d", $number);
	return;
}
sub p{
    return () if($File::Find::dir =~ m#^/home/foltia/php/tv/nas#);
    return () if($File::Find::dir =~ m#^/home/foltia/php/tv/mita#);
    return @_;
}
sub t{
	return if($_ eq '.');
	return if($_ eq '..');
	rmdir  $File::Find::name if(-d);
	my $r = readlink($_);
	unlink $File::Find::name if(-l && ! -f $r);
	return;
}
sub getq {
	my $m = shift;
	return unless($m);
	return 1 if($m == 1 || $m == 2 || $m == 3);
	return 2 if($m == 4 || $m == 5 || $m == 6);
	return 3 if($m == 7 || $m == 8 || $m == 9);
	return 4 if($m == 10 || $m == 11 || $m == 12);
	return 0;
}
sub d{
	my $destdir;
	return if($_ eq '.');
	return if($_ eq '..');
	my $file = $_;
	return unless(-f);
	return unless(/$regex/);

	s/^(MAQ|MHD)\-//;
	return unless (/^(\d+)\-(\d+)?\-(\d+)?\-(\d+)/);
	my @tag = split( /\-/, $_);
	my $number = shift @tag;
	my $tail = pop @tag;
	my $time = pop @tag;
	my $day = pop @tag;
	my $no = pop @tag || '';
	my ($ch, $ext) =  split( /\./, $tail);
	&tid_to_name($number);
	my $cat = $tid->{$number}->{cat};
	my $FirstYear = $tid->{$number}->{FirstYear};
	my $FirstMonth = $tid->{$number}->{FirstMonth};
	my $FirstEndYear = $tid->{$number}->{FirstEndYear};
	my $FirstEndMonth = $tid->{$number}->{FirstEndMonth};
	$FirstYear     = 'XXXXXX' if (ref($FirstYear) eq "HASH");
	$FirstMonth    = '0' if (ref($FirstMonth) eq "HASH");
	$FirstEndYear  = '' if (ref($FirstEndYear) eq "HASH");
	$FirstEndMonth = '0' if (ref($FirstEndMonth) eq "HASH");
	my $title = $tid->{$number}->{title};
	my $filename = sprintf "%s #%s %s-%s %sch.%s", $title, $no, $day, $time, $ch, $ext;
	my $src = $File::Find::name;
	if($nomakedir)
	{
		$destdir = $dept;
		my $dst = $destdir . '/' . $filename;
		unlink $dst if (-e $dst && -l $dst);
		symlink $src, $dst;
		return;
	}
	else
	{
		my $firstq = &getq($FirstMonth);
		my $endq = &getq($FirstEndMonth);
		my $firstyq = 'XXXXXX';
		my $endyq = 'XXXXXX';
		$firstyq = sprintf "%s_%dQ", $FirstYear,  $firstq if($firstq);
		$endyq   = sprintf "%s_%dQ", $FirstEndYear, $endq if($endq);
		
		my @dirs;
		push @dirs, sprintf "%s_%s", $firstyq, $endyq if ($firstyq ne $endyq);
		push @dirs, $firstyq;
		push @dirs, $endyq;
		
		foreach my $subdir(@dirs) {
			$destdir =  $dept . $cat{$cat} . '/' . $subdir . '/' . $title ;
			mkpath(($destdir));
			$destdir = $dept unless(-d $destdir);
			my $dst = $destdir . '/' . $filename;
			if (-e $dst && -l $dst)
			{
				my $r = readlink($dst);
				unlink $dst if($r ne $src);
			}
			symlink $src, $dst unless(-e $dst);
		}
		return;
		
	}
}
sub main
{
	eval { $tid = lock_retrieve($tiddb) if(-f $tiddb); };
	if($@) { unlink $tiddb; };
	finddepth( { preprocess => \&p, wanted => \&t, nochdir => 0}, $dept );
	finddepth( { preprocess => \&p, wanted => \&d, nochdir => 0}, $tv );
	lock_nstore $tid, $tiddb;
}
&main;

