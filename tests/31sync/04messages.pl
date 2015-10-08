test "Can sync a room with a single message",
    requires => [qw( first_api_client can_sync )],
    check => sub {
        my ( $http ) = @_;
        my ( $user, $filter_id, $room_id, $event_id );
        matrix_register_sync_user( $http )->then( sub {
            ( $user ) = @_;
            matrix_create_room( $user )
        })->then( sub {
            ( $room_id ) = @_;
            matrix_send_room_text_message( $user, $room_id,
                body => "A test message",
            )
        })->then( sub {
            ( $event_id ) = @_;
            matrix_create_filter( $user, {
                room => { timeline => { limit => 1 }}
            })
        })->then( sub {
            ( $filter_id ) = @_;
            matrix_sync( $user, filter => $filter_id )
        })->then( sub {
            my ( $body ) = @_;
            my $room = $body->{rooms}{joined}{$room_id};
            require_json_keys( $room, qw( event_map timeline state ephemeral ));
            require_json_keys( $room->{timeline}, qw( events limited prev_batch ));
            @{$room->{timeline}{events}} == 1
                or die "Expected only one timeline event";
            $room->{timeline}{events}[0] eq $event_id
                or die "Unexpected timeline event";
            $room->{event_map}{$event_id}{content}{body} eq "A test message"
                or die "Unexpected message body.";
            $room->{timeline}{limited}
                or die "Expected timeline to be limited";
            Future->done(1)
        })
    };


test "Can sync a room with a message with a transaction id",
    requires => [qw( first_api_client can_sync )],
    check => sub {
        my ( $http ) = @_;
        my ( $user, $filter_id, $room_id, $event_id );
        matrix_register_sync_user( $http )->then( sub {
            ( $user ) = @_;
            matrix_create_room( $user )
        })->then( sub {
            ( $room_id ) = @_;
            matrix_send_room_text_message( $user, $room_id,
                body => "A test message", txn_id => "my_transaction_id"
            )
        })->then( sub {
            ( $event_id ) = @_;
            matrix_create_filter( $user, {
                room => {
                    timeline => { limit => 1 },
                    state => { types => [] }
                },
                presence => { types => [] }
            })
        })->then( sub {
            ( $filter_id ) = @_;
            matrix_sync( $user, filter => $filter_id )
        })->then( sub {
            my ( $body ) = @_;
            my $room = $body->{rooms}{joined}{$room_id};
            require_json_keys( $room, qw( event_map timeline state ephemeral ));
            require_json_keys( $room->{timeline}, qw( events limited prev_batch ));
            @{$room->{timeline}{events}} == 1
                or die "Expected only one timeline event";
            $room->{timeline}{events}[0] eq $event_id
                or die "Unexpected timeline event";
            $room->{event_map}{$event_id}{content}{body} eq "A test message"
                or die "Unexpected message body.";
            $room->{event_map}{$event_id}{unsigned}{transaction_id} eq "my_transaction_id"
                or die "Unexpected transaction id";
            $room->{timeline}{limited}
                or die "Expected timeline to be limited";
            Future->done(1)
        })
    };


test "A message sent after an initial sync appears in the timeline of an incremental sync.",
    requires => [qw( first_api_client can_sync )],
    check => sub {
        my ( $http ) = @_;
        my ( $user, $filter_id, $room_id, $event_id, $next_batch );
        matrix_register_sync_user( $http )->then( sub {
            ( $user ) = @_;
            matrix_create_room( $user )
        })->then( sub {
            ( $room_id ) = @_;
            matrix_create_filter( $user, {
                room => {
                    timeline => { limit => 1 },
                    state => { types => [] }
                },
                presence => { types => [] }
            })
        })->then( sub {
            ( $filter_id ) = @_;
            matrix_sync( $user, filter => $filter_id )
        })->then( sub {
            my ( $body ) = @_;
            $next_batch = $body->{next_batch};
            matrix_send_room_text_message( $user, $room_id,
                body => "A test message", txn_id => "my_transaction_id"
            )
        })->then( sub {
            ( $event_id ) = @_;
            matrix_sync( $user, filter => $filter_id, since => $next_batch )
        })->then( sub {
            my ( $body ) = @_;
            my $room = $body->{rooms}{joined}{$room_id};
            require_json_keys( $room, qw( event_map timeline state ephemeral ));
            require_json_keys( $room->{state}, qw( events ));
            require_json_keys( $room->{timeline}, qw( events limited prev_batch ));
            @{$room->{state}{events}} == 0
                or die "Did not expect a state event";
            @{$room->{timeline}{events}} == 1
                or die "Expected only one timeline event";
            $room->{timeline}{events}[0] eq $event_id
                or die "Unexpected timeline event";
            $room->{event_map}{$event_id}{content}{body} eq "A test message"
                or die "Unexpected message body.";
            $room->{event_map}{$event_id}{unsigned}{transaction_id} eq "my_transaction_id"
                or die "Unexpected transaction id";
            (not $room->{timeline}{limited})
                or die "Did not expect timeline to be limited";
            Future->done(1)
        })
    };