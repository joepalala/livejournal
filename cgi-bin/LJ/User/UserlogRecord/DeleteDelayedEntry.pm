package LJ::User::UserlogRecord::DeleteDelayedEntry;
use strict;
use warnings;

use base qw( LJ::User::UserlogRecord );

sub action {'delete_delayed_entry'}
sub group  {'entries'}

sub translate_create_data {
    my ( $class, %data ) = @_;

    $data{'actiontarget'} = delete $data{'delayedid'};
    $data{'extra'}        = { 'method' => delete $data{'method'} };

    return %data;
}

sub description {
    my ($self) = @_;

    my $targetid = $self->actiontarget;

    my $extra    = $self->extra_unpacked;
    my $method   = $extra->{'method'};

    return LJ::Lang::ml( 'userlog.action.deleted.delayed.entry', { targetid => $targetid, method => $method } );
}

1;
