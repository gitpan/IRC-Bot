package IRC::Bot;

use strict;
use warnings;
#use diagnostics;  # For development
use vars qw($VERSION @ISA @EXPORT $log $seen $auth $help);
use Carp;
use POE;
use POE::Component::IRC;
use POSIX qw( setsid );
use IRC::Bot::Log;
use IRC::Bot::Seen;
use IRC::Bot::Auth;
use IRC::Bot::Help;
use constant NICK => 'bot';

require Exporter;

@ISA     = qw(Exporter AutoLoader);
@EXPORT  = qw();
$VERSION = '0.03';

# Set us up the bomb
sub new {

    my $class = shift;
    my %args  = @_;
    return bless \%args, $class;

}

# Run the bot
sub run {

    my $self = shift;

    $log  = IRC::Bot::Log->new( 'Path' => $self->{'LogPath'} );
    $seen = IRC::Bot::Seen->new();
    $auth = IRC::Bot::Auth->new();
    $help = IRC::Bot::Help->new();

    POE::Component::IRC->new( NICK )
      || croak "Cannot create new P::C::I object!\n";

    POE::Session->create(
        object_states => [
            $self => {
                _start           => "bot_start",
                irc_001          => "on_connect",
                irc_disconnected => "on_disco",
                irc_public       => "on_public",
                irc_msg          => "on_msg",
                irc_quit         => "on_quit",
                irc_join         => "on_join",
                irc_part         => "on_part",
                irc_ctcp_ping    => "on_ping",
                irc_ctcp_version => "on_ver",
                irc_ctcp_finger  => "on_finger",
                irc_ctcp_page    => "on_page",
                irc_ctcp_time    => "on_time",
                irc_nick         => "on_nick",
                keepalive        => "keepalive",
                irc_433          => "on_nick_taken",
                irc_353          => "on_names",
                irc_dcc_request  => "on_dcc_req",
                irc_dcc_error    => "on_dcc_err",
                irc_dcc_done     => "on_dcc_done",
                irc_dcc_start    => "on_dcc_start",
                irc_dcc_chat     => "on_dcc_chat",

            }
        ]
    );
    $poe_kernel->run();
}

# Start the bot things up
sub bot_start {

    my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];

    my $ts = scalar(localtime);
    $log->serv_log("[$ts] Starting Up...");

    $kernel->post( NICK, 'register', 'all' );
    $kernel->post(
        NICK,
        'connect',
        {
            Debug    => $self->{'Debug'},
            Nick     => $self->{'Nick'},
            Server   => $self->{'Server'},
            Port     => $self->{'Port'},
            Username => $self->{'User'},
            Ircname  => $self->{'Ircname'}
        }
    );
    $kernel->delay( 'reconnect', 20 );
}

# Handle connect event
# Join specified channels
sub on_connect {

    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    $kernel->post( NICK, 'mode', $self->{'Nick'}, '+B' );
    foreach my $chan ( @{ $self->{'Channels'} } ) {
        $kernel->post( NICK, 'join', $chan );
    }
}

# Someone pinged us, handle it.
sub on_ping {

    my ( $self, $kernel, $who ) = @_[ OBJECT, KERNEL, ARG0 ];
    my $nick = ( split /!/, $who )[0];
    $kernel->post( NICK, 'ctcpreply', $nick, "PING", "PONG" );

}

# Someone changed their nick, handle it.
sub on_nick {

    my ( $self, $kernel, $who, $nnick ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my $nick = ( split /!/, $who )[0];
    $seen->log_seen( $nick, "Changing nick to $nnick" );

}

# Handle CTCP Version
sub on_ver {

    my ( $self, $kernel, $who ) = @_[ OBJECT, KERNEL, ARG0 ];
    my $nick = ( split /!/, $who )[0];
    $kernel->post( NICK, 'ctcpreply', $nick, "VERSION", "Ima Bot" );

}

# Handle CTCP Finger
sub on_finger {

    my ( $self, $kernel, $who ) = @_[ OBJECT, KERNEL, ARG0 ];
    my $nick = ( split /!/, $who )[0];
    $kernel->post( NICK, 'ctcpreply', $nick, "FINGER", "Ima Bot" );

}

# Handle CTCP Page
sub on_page {

    my ( $self, $kernel, $who ) = @_[ OBJECT, KERNEL, ARG0 ];
    my $nick = ( split /!/, $who )[0];
    $kernel->post( NICK, 'ctcpreply', $nick, "PAGE", "Ima Bot" );

}

# Handle CTCP Time
sub on_time {

    my ( $self, $kernel, $who ) = @_[ OBJECT, KERNEL, ARG0 ];
    my $nick = ( split /!/, $who )[0];
    my $ts = scalar(localtime);
    $kernel->post( NICK, 'ctcpreply', $nick, "TIME", $ts );

}

# Handle someone quitting.
sub on_quit {

    my ( $self, $kernel, $who, $msg ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my $nick = ( split /!/, $who )[0];
    $log->serv_log("$nick Quit: $msg");
    $seen->log_seen( $nick, "Quit: $msg" );

}

# Handle join event
sub on_join {

    my ( $self, $kernel, $who, $where ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my $nick = ( split /!/, $who )[0];
    $log->chan_log("$nick Joining $where");
    $seen->log_seen( $nick, "Joining $where" );

}

# Handle part event
sub on_part {

    my ( $self, $kernel, $who, $where ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my $nick = ( split /!/, $who )[0];
    $log->chan_log("$nick Parting $where");
    $seen->log_seen( $nick, "Parting $where" );

}

# Changes nick if current nick is taken
sub on_nick_taken {

    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    my $nick  = $self->{'Nick'};
    my $rnick = int( rand(999) );
    $kernel->post( NICK, 'nick', "$nick$rnick" );

}

# Communicate with channel/nick
sub botspeak {

    my ( $self, $kernel, $channel, $msg ) = @_;
    $kernel->post( NICK, 'privmsg', $channel, $msg );

}

# Borrowed this code from another bot
# Can't for the life of me remember which one
# Please, let me know if it was you, so I can
# give props!!
sub keepalive {

    my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];
    $heap->{'keepalive_time'} += 180;
    $kernel->alarm( 'keepalive' => $heap->{'keepalive_time'} );
    $kernel->post( NICK, 'sl', 'PING ' . time() );

}

# Handle public events
sub on_public {

    my ( $self, $kernel, $who, $where, $msg ) =
      @_[ OBJECT, KERNEL, ARG0 .. $#_ ];
    my $nick    = ( split /!/, $who )[0];
    my $channel = $where->[0];
    my $pubmsg  = $msg;
    my $time = sprintf("%02d:%02d", ( localtime( time() ) )[ 2, 1 ] );
    $log->chan_log("[$channel $time] <$nick> $msg");

    if ( $msg =~ m/^!help$/i ) {

        my %pubHelp = $help->pub_help();
        $self->botspeak( $kernel, $channel, "Here is the help you requested:" );
        foreach my $keys ( keys %pubHelp ) {
            $self->botspeak( $kernel, $channel, $pubHelp{$keys} );
        }

    }
    elsif ( $msg =~ m/^!ping$/i ) {

        $self->botspeak( $kernel, $channel, "Pong!" );

    }
    elsif ( $msg =~ m/^!uptime$/i ) {

        my $time = sprintf( "%d Days, %02d:%02d:%02d",
            ( gmtime( time() - $^T ) )[ 7, 2, 1, 0 ] );
        $self->botspeak( $kernel, $channel, "I've been up for $time" );

    }
    elsif ( $msg =~ m/^!seen/i ) {

        my @arg  = split ( / /, $msg );
        my $name = $arg[1];

        if ($name) {

            my $fseen = $seen->get_seen($name) || undef;

            if ( $name eq $nick ) {
                $self->botspeak( $kernel, $channel,
                    "Looking for yourself, $nick?" );
            }
            elsif ( $name eq $self->{'Nick'} ) {
                $self->botspeak( $kernel, $channel, "I'm right here, foo!" );
            }
            elsif ( defined $fseen ) {
                $self->botspeak( $kernel, $channel, $fseen );
            }
            else {
                $self->botspeak( $kernel, $channel,
                    "Sorry, $nick, I haven't seen $name." );
            }
        }
        else {
            my $seen = $help->pub_help('seen');
            $self->botspeak( $kernel, $channel, "Hey $nick, it's like this: $seen" );
        }
    }
}

# Handle privmsg communication.
sub on_msg {

    my ( $self, $kernel, $who, $nicks, $msg ) =
      @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2 ];
    my $nick = ( split /!/, $who )[0];

    $self->botspeak( $kernel, $nick,
        "Please use DCC CHAT to communicate with me :)" )

}

# Handle dcc request, accept and move on.
sub on_dcc_req {

    my ( $self, $kernel, $type, $who, $id ) =
      @_[ OBJECT, KERNEL, ARG0, ARG1, ARG3 ];

    $kernel->post( NICK, 'dcc_accept', $id );

}

# Start up the DCC session, or welcome back
sub on_dcc_start {

    my ( $self, $kernel, $id, $who, $type ) =
      @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2 ];
    my $nick = ( split /!/, $who )[0];

    if ( $type eq 'CHAT' ) {
        my $check = $auth->is_auth($nick);

        if ( $check != 1 ) {
            $kernel->post( NICK, 'dcc_chat', $id, "Please Login" );
            $kernel->post( NICK, 'dcc_chat', $id, "(.login user pass)" );
        }
        else {
            $auth->get_ses($nick);
            $kernel->post( NICK, 'dcc_chat', $id, "Welcome Back, $nick" );
        }

    }
    else {
        $kernel->post( NICK, 'dcc_close', $id );
    }

}

# Handle a dcc_chat session, parse for commands
# Act accordingly.
# LOTS OF STUFF GOING ON HERE
# Main command parser/dispatcher
sub on_dcc_chat {

    my ( $self, $kernel, $id, $who, $msg ) =
      @_[ OBJECT, KERNEL, ARG0, ARG1, ARG3 ];

    my $nick  = ( split /!/, $who )[0];
    my $check = $auth->is_auth($nick);

    if ( $msg =~ m/^.login/i ) {

        my @arg  = split ( / /, $msg );
        my $user = $arg[1];
        my $pass = $arg[2];

        if ( $user eq $self->{'Admin'} && $pass eq $self->{'Apass'} ) {
            $kernel->post( NICK, 'dcc_chat', $id, "Welcome, $nick!" );
            $kernel->post( NICK, 'dcc_chat', $id,
                "All commands are prefixed with a period(.)" );
            $kernel->post( NICK, 'dcc_chat', $id, "See \cB.help\cB" );
            $log->bot_log("$nick logged in with $user && $pass");
            $auth->auth_set($nick);
        }
        else {
            $kernel->post( NICK, 'dcc_chat', $id, "Incorrect Login Info!" );
            $log->bot_log("$nick tried to login with $user && $pass");
            $kernel->post( NICK, 'dcc_close', $id );
        }
    }
    elsif ( $check != 0 ) {

        if ( $msg =~ m/^.say/i ) {

            my @arg = split ( / /, $msg );
            my $chan = $arg[1];
            $msg =~ s/$arg[1]//;
            $msg =~ s/.say\s*//;
            $msg =~ s/\n+//;

            if ( $chan || $arg[2] ) {
                $self->botspeak( $kernel, $chan, $msg );
            }
            else {
                my $say = $help->ask_help('say');
                $kernel->post( NICK, 'dcc_chat', $id, $say );
            }
        }
        elsif ( $msg =~ m/^.logout$/i ) {

            $kernel->post( NICK, 'dcc_chat', $id, "Bye Bye" );
            $auth->de_auth($nick);
            $kernel->post( NICK, 'dcc_close', $id );

        }
        elsif ( $msg =~ m/^.join/i ) {

            my @arg  = split ( / /, $msg );
            my $chan = $arg[1];

            if ($chan) {
                $kernel->post( NICK, 'join', $chan );
            }
            else {
                my $join = $help->ask_help('join');
                $kernel->post( NICK, 'dcc_chat', $id, $join );
            }
        }
        elsif ( $msg =~ m/^.part/i ) {

            my @arg  = split ( / /, $msg );
            my $chan = $arg[1];

            if ($chan) {
                $kernel->post( NICK, 'part', $chan );
            }
            else {
                my $part = $help->ask_help('part');
                $kernel->post( NICK, 'dcc_chat', $id, $part );
            }
        }
        elsif ( $msg =~ m/^.help/i ) {

            my @arg     = split ( / /, $msg );
            my $command = $arg[1];

            if ($command) {
                if ( $command eq 'all' ) {
                    my %help = $help->ask_help();
                    $kernel->post( NICK, 'dcc_chat', $id,
                        "Available Topics Are:" );
                    foreach my $keys ( keys %help ) {
                        $kernel->post( NICK, 'dcc_chat', $id, "\cB$keys" );
                    }
                    $kernel->post( NICK, 'dcc_chat', $id,
                        "Type .help <topic> for more info" );
                }
                else {
                    my $ans = $help->ask_help($command);
                    $kernel->post( NICK, 'dcc_chat', $id, $ans );
                }
            }
            else {
                $kernel->post( NICK, 'dcc_chat', $id,
                    "Try .help all or .help <command> for more help." );
            }
        }
        elsif ( $msg =~ m/^.quit/i ) {

            my @arg = split ( / /, $msg );
            my $mesg = $arg[1];
            $msg =~ s/.quit\s*//;
            $msg =~ s/\n+//;

            if ($mesg) {
                $kernel->call( NICK, 'quit', $msg );
            }
            else {
                $kernel->call( NICK, 'quit', "IRC::BOT" );
            }
        }
        elsif ( $msg =~ m/^.clear\s+\w$/i || $msg =~ m/^.clear/i ) {

            my @arg   = split ( / /, $msg );
            my $file  = $arg[1];
            my $clear = $log->clear_log($file);

            if ( $clear != 0 ) {
                $kernel->post( NICK, 'dcc_chat', $id, "Cleared $file" );
            }
            else {
                my $clear = $help->ask_help('clear');
                $kernel->post( NICK, 'dcc_chat', $id, $clear );
            }
        }
        elsif ( $msg =~ m/^.kick/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $user    = $arg[2];
            my $mesg    = $arg[3];
            if ( $channel || $user || $mesg ) {
                $kernel->post( NICK, 'kick', $channel, $user, $mesg );
            }
            else {
                my $kick = $help->get_help('kick');
                $kernel->post( NICK, 'dcc_chat', $id, $kick );
            }
        }
        elsif ( $msg =~ m/^.op/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $user    = $arg[2];
            if ( $channel || $user ) {
                $kernel->post( NICK, 'mode', $channel, '+o', $user );
            }
            else {
                my $op = $help->ask_help('op');
                $kernel->post( NICK, 'dcc_chat', $id, $op );
            }
        }
        elsif ( $msg =~ m/^.deop/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $user    = $arg[2];
            if ( $channel || $user ) {
                $kernel->post( NICK, 'mode', $channel, '-o', $user );
            }
            else {
                my $deop = $help->ask_help('deop');
                $kernel->post( NICK, 'dcc_chat', $id, $deop );
            }
        }
        elsif ( $msg =~ m/^.ban/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $host    = $arg[2];
            if ( $channel || $host ) {
                $kernel->post( NICK, 'mode', $channel, '+b', $host );
            }
            else {
                my $ban = $help->ask_help('ban');
                $kernel->post( NICK, 'dcc_chat', $id, $ban );
            }

        }
        elsif ( $msg =~ m/^.unban/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $host    = $arg[2];
            if ( $channel || $host ) {
                $kernel->post( NICK, 'mode', $channel, '-b', $host );
            }
            else {
                my $unban = $help->ask_help('unban');
                $kernel->post( NICK, 'dcc_chat', $id, $unban );
            }
        }
        elsif ( $msg =~ m/^.hop/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $user    = $arg[2];

            if ( $channel || $user ) {
                $kernel->post( NICK, 'mode', $channel, '+h', $user );
            }
            else {
                my $hop = $help->ask_help('hop');
                $kernel->post( NICK, 'dcc_chat', $id, $hop );
            }
        }
        elsif ( $msg =~ m/^.dehop/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $user    = $arg[2];

            if ( $channel || $user ) {
                $kernel->post( NICK, 'mode', $channel, '-h', $user );
            }
            else {
                my $dehop = $help->ask_help('dehop');
                $kernel->post( NICK, 'dcc_chat', $id, $dehop );
            }
        }
        elsif ( $msg =~ m/^.voice/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $user    = $arg[2];

            if ( $channel || $user ) {
                $kernel->post( NICK, 'mode', $channel, '+v', $user );
            }
            else {
                my $voice = $help->ask_help('voice');
                $kernel->post( NICK, 'dcc_chat', $id, $voice );
            }

        }
        elsif ( $msg =~ m/^.devoice/i ) {

            my @arg     = split ( / /, $msg );
            my $channel = $arg[1];
            my $user    = $arg[2];

            if ( $channel || $user ) {
                $kernel->post( NICK, 'mode', $channel, '-v', $user );
            }
            else {
                my $devoice = $help->ask_help('voice');
                $kernel->post( NICK, 'dcc_chat', $id, $devoice );
            }

        }
        elsif ( $msg =~ m/^.away/i ) {

            my @arg  = split ( / /, $msg );
            my $amsg = $arg[1];

            if ($amsg) {
                $kernel->post( NICK, 'away', $amsg );
            }
            else {
                my $away = $help->ask_help('away');
                $kernel->post( NICK, 'dcc_chat', $id, $away );
            }

        }
        elsif ( $msg =~ m/^.back$/i ) {

            $kernel->post( NICK, 'away' );

        }
        elsif ( $msg =~ m/^.uptime$/i ) {

            my $time = sprintf( "%d Days, %02d:%02d:%02d",
                ( gmtime( time() - $^T ) )[ 7, 2, 1, 0 ] );
            $kernel->post( NICK, 'dcc_chat', $id, "I've been up for $time" );
        }
        elsif ( $msg =~ m/^.clearseen$/i ) {

            $seen->clear_seen();
            $kernel->post( NICK, 'dcc_chat', $id, "Seen cache cleared!" );

        }
        elsif ( $msg =~ m/^.topic/i ) {
            my @arg  = split ( / /, $msg );
            my $chan = $arg[1];
            $msg =~ s/\.topic\s+//;
            $msg =~ s/$chan//;
            $msg =~ s/\n+//;
            if ( $msg ) {
                $kernel->post( NICK, 'topic', $chan, $msg );
            }
            else {
                my $topic = $help->ask_help('topic');
                $kernel->post( NICK, 'dcc_chat', $id, $topic );
            }
        }
        else {

            $kernel->post( NICK, 'dcc_chat', $id,
                "\cB.help\cB is what you need" );
        }
    }
    else {

        $kernel->post( NICK, 'dcc_chat', $id, "Unauthorized!" );
        $kernel->post( NICK, 'dcc_close', $id );
    }
}

# Got an error, attempt to close session.
# Doesn't appear to be working, I need to question
# my implementation, but we'll do that later
sub on_dcc_err {

    my ( $self, $kernel, $id, $who ) = @_[ OBJECT, KERNEL, ARG0, ARG2 ];
    my $nick = ( split /!/, $who )[0];
    $kernel->post( NICK, 'notice', $nick, "Bot Session Closed" );
    $auth->de_auth($nick);

}

# DCC session is done, close out, kill session.
sub on_dcc_done {

    my ( $self, $kernel, $id, $who ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my $nick = ( split /!/, $who )[0];
    $auth->de_auth($nick);

}

# Got back info from the NAMES command.
# Parse and send info to Seen.pm
sub on_names {

    my ($self, $kernel, $sender, $server, $who) = 
        @_[OBJECT, KERNEL, SENDER, ARG0..ARG1];

    $who =~ /([^"]*)\s+:([^"]*)\s+/;
    my $chan = $1;
    my $names = $2;
    $seen->load_current( $names, $chan );

}

# Daemonize process
# Got this off of perlmonks
# Node id: 121604 tailored to my needs
# Was trying to avoid more dependencies.
sub daemon {

    my $self = shift;
    
    my @fh = ( \*STDIN, \*STDOUT );

    my $path;
    $self->{'LogPath'} eq 'null' ? $path = $ENV{'HOME'} :  $path = $self->{'LogPath'};
    open \*STDERR, ">$path/error.log";
    select((select(\*STDERR), $| = 1)[0]);
    
    my $ppid = $$;

    my $pid = fork && exit 0;

    ! defined $pid && croak "No Fork: ", $!;

    while (kill 0, $ppid) {
        select undef, undef, undef, .001;
    };

    my $session_id = POSIX::setsid();
    chdir '/' || croak "Could not cd to /", $!;
    my $oldmask = umask 00;
    close $_ || croak $! for @fh;

}

# Disconnected, clean up a bit
sub on_disco {
 
    my $self = shift;
    $auth->de_auth();
    exit(0);

}

1;

__END__

=head1 NAME

IRC::Bot - Channel Maintenance IRC bot.

=head1 SYNOPSIS

  #!/usr/bin/perl -w
  use strict;
  use IRC::Bot;

  # Initialize new object
  my $bot = IRC::Bot->new( Debug    => 0,
                           Nick     => 'MyBot',
                           Server   => 'irc.myserver.com',
                           Pass     => 'myircpassword',
                           Port     => '6667',
                           Username => 'MyBot',
                           Ircname  => 'MyBot',
                           Admin    => 'admin',
                           Apass    => 'iamgod',
                           Channels => [ '#mychan', '#test' ],
                           LogPath  => '/home/myhome/bot/log/',
                        );

  # Daemonize process 
  $bot->daemon();

  # Run the bot
  $bot->run();

  __END__

=head1 DESCRIPTION

A complete bot, similar to eggdrop using POE::Component::IRC.
Allows access to all channel user management modes.  Provides !seen functions, a complete help system, logging, dcc chat interface, and it runs as a
daemon process.  IRC::Bot utilizes Cache::FileCache for seen functions, 
and for session handling.

=head1 METHODS/OPTIONS

=over

=item new()

B<new()> Initializes the object, takes bunches of parameters to make
things work, see SYNOPSIS for usage.

=back

=head2 Parameters

=over

I<Debug> Tells P::C::I to output the messaging between client/server.  Outputs to error.log.


I<Nick> The nick you want your bot to go by.


I<Server> The server you want to connect the bot to.


I<Pass> ~Optional~ Sets the password for a password protected server.


I<Port> Port to connect on server.


I<Username> Username for display in /whois .


I<Ircname> Also for /whois display.


I<Admin> Admin name for bot access.


I<Apass> Password for admin access.


I<Channels> List of channels to join, takes as many as you want to fit.


I<LogPath> ~Optional~ The absolute path of where to open log files.  If 
set to 'null', nothing is logged, and error.log will be put in your 
$ENV{'HOME'} directory.

=back

=over

=item daemon()

B<daemon()> Sets process as a daemon.

=item run()

B<run()> Starts bot up, registers events, and tons of other neat stuff.

=back

=head1 CREDITS

Thanks to Perlmonks.org for education/support/ideas.
Thanks to Danyeal for being patient with me, and loving me.

=head1 AUTHOR

Benjamin Smith (DeFyance) defyance@just-another.net

=head1 SEE ALSO

POE::Component::IRC Cache::FileCache

=cut
