#!/usr/bin/perl -w
use strict;
use IRC::Bot;

my $bot = IRC::Bot->new(      
                         Debug    => 0,
                         Nick     => 'TestBot',
     	     	         Server   => 'irc.slashnet.org',
			 Pass     => '',
                         Port     => '6667',
                         Username => 'TestBot',
                         Ircname  => 'TestBot',
			 Admin    => 'admin',
			 Apass    => 'changeme',
			 Channels => [ '#DefTest' ],
			 LogPath  => '/home/mydir/botlog/',
                       );
$bot->daemon();
$bot->run();
