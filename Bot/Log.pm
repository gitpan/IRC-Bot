package IRC::Bot::Log;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT);
use Carp;

require Exporter;

@ISA     = qw(Exporter AutoLoader);
@EXPORT  = qw();
$VERSION = '0.02';

# Set us up the bomb
sub new {

    my $class = shift;
    my %args = @_;
    return bless \%args, $class;

}

sub list {

    my $self = shift;
    my $blog = $self->{'Path'} . "bot.log";
    my $slog = $self->{'Path'} . "server.log";
    my $clog = $self->{'Path'} . "channel.log";
    my %list = (
        'Bot'     => $blog,
        'Server'  => $slog,
        'Channel' => $clog
    );
    return %list;

}

# Start things up
# Check for existing log files
# Create new ones, if need be
sub _load {

    my $self = shift;
    my %list = $self->list();

    if ( $self->{'Path'} ne 'null' ) {
        foreach ( keys %list ) {
            if ( -e $_ ) {
                open( FILE, $_ ) || croak "Cannot Open $_!";
                print FILE "Bot loaded...\n";
                close(FILE) || croak "Cannot Close $_!";
            }
        }
    }
    else {
        return 0;
    }
}

# Dump seen info into file
sub bot_log {

    my ( $self, $message ) = @_;
    my %list = $self->list();

    if ( $self->{'Path'} ne 'null' ) {
        open( FILE, ">>$list{'Bot'}" ) || croak "Cannot Open $list{'Bot'}!";
        print FILE "$message\n";
        close(FILE) || croak "Cannot Close $list{'Bot'}!";
    }
    else {
        return 0;
    }
}

sub serv_log {

    my ( $self, $message ) = @_;
    my %list = $self->list();

    if ( $self->{'Path'} ne 'null' ) {
        open( FILE, ">>$list{'Server'}" ) || croak "Cannot Open $list{'Server'}!";
        print FILE "$message\n";
        close(FILE) || croak "Cannot Close $list{'Server'}!";
    }
    else {
        return 0;
    }
}

sub chan_log {

    my ( $self, $message ) = @_;
    my %list = $self->list();

    if ( $self->{'Path'} ne 'null' ) {
        open( FILE, ">>$list{'Channel'}" ) || croak "Cannot Open $list{'Channel'}!";
        print FILE "$message\n";
        close(FILE) || croak "Cannot Close $list{'Channel'}!";
    }
    else {
        return 0;
    }
}

# Clear logfile of unwanted seen data
sub clear_log {

    my ( $self, $arg ) = @_;
    my %list = $self->list();

    if ( $arg eq 'All' ) {
        foreach ( keys %list ) {
            unlink($_) || croak "Cannot Unlink $_!";
        }
    }
    else {
        if ( exists $list{$arg} ) {
            unlink( $list{$arg} ) || croak "Cannot Unlink $arg!";
            return 1;
        }
        else {
            return 0;
        }
    }

}

1;
__END__

=pod

=head1 NAME

Log.pm A module to provide logging methods for IRC::Bot

=head1 SYNOPSIS

  use Irc::Bot::Log;
  my $log = Irc::Bot::Log->new( Path => '/path/to/logdir/' );

  # later on...

  # Log join event, assuming Poe::Component::IRC use..
  sub on_join {
    my ( $kernel, $who, $where ) = @_[ KERNEL, ARG0, ARG1 ];
    my $nick = ( split /!/, $who )[0];
    
    # Do Stuff...

    $log->chan_log( "$nick has joined $where\n" );

  }

=head1 DESCRIPTION

Provides logging functionality for an IRC bot.

=head1 METHODS

=over 4

=item 1

B<bot_log()> logs private messages to the bot

Use like so:

 $log->bot_log( "Lamer tried to access me!\n" );

=item 2

B<serv_log()> Logs server events like disconnects, connects, connection 
errors and such.

=item 3

B<chan_log()> Logs channel activity, just about everything.

Use like so:

 $log->chan_log( "$nick joined $channel\n" );

=item 4

B<clear_log()> clears the specified log file.  Arguments are:

Bot for bot.log
Server for server.log
Channel for chan.log
All to clear all the logs

Use like so:

 $log->clear_log("Bot");

=back

=head1 AUTHOR

Benjamin Smith (DeFyance) defyance@just-another.net

=head1 SEE ALSO

POE::Component::IRC

=cut
