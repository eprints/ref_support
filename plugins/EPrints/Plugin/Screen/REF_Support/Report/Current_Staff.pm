package EPrints::Plugin::Screen::REF_Support::Report::Current_Staff;

use EPrints::Plugin::Screen::REF_Support::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Report' );

use strict;

sub export
{
        my( $self, $fh, $skip_intro ) = @_;

        my $plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $plugin;

	if( defined $fh )
	{
	        $plugin->output_list(
        	        list => $self->users,
	                fh => $fh,
			benchmark => $self->{processor}->{benchmark},
			skip_intro => $skip_intro,
		);
	}
	else
	{
        	$plugin->initialise_fh( \*STDOUT );
	        $plugin->output_list(
        	        list => $self->users,
	                fh => \*STDOUT,
			benchmark => $self->{processor}->{benchmark},
			skip_intro => $skip_intro,
	        );
	}
}

sub properties_from
{
	my( $self ) = @_;

	# will be used by the SUPER class:
	$self->{processor}->{report} = 'ref1_current_staff';

	$self->SUPER::properties_from;
}

# returns the users belonging to the selected UoA's, regardless of whether they've made selections or not, and where end date is not set, or is after 31 July 2020
sub users_by_uoa
{
        my( $self ) = @_;

        my @uoas = @{ $self->{processor}->{uoas} || [] };

        my @uoa_ids = map { $_->id } @uoas;

        my $users = $self->{session}->dataset( 'user' )->search( filters => [
                { meta_fields => [ "ref_support_uoa" ], value => join( " ", @uoa_ids ),},
        ]);

	#now filter out users who have an end date of before 31 July 2020
	my $former_users = $self->{session}->dataset( 'user' )->search( filters => [
                { meta_fields => [ "ref_support_uoa" ], value => join( " ", @uoa_ids ),},
                { meta_fields => [ "ref_end_date" ], value => '-2020-07-31', match => "IN" },
        ]);

	$users = $users->remainder( $former_users );

        return $users->reorder( "ref_support_uoa/name" );
}

sub ajax_user
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $json = { data => [] };

	$session->dataset( "user" )
	->list( [$session->param( "user" )] )
	->map(sub {
		(undef, undef, my $user) = @_;

		return if !defined $user; # odd

		my @problems;

		my $userid = $user->get_id;

		my $frag = $self->render_user( $user, \@problems );

		my @json_problems;
		foreach my $problem (@problems)
		{
			next unless( EPrints::Utils::is_set( $problem ) );

			my $problem_data = {
				desc => EPrints::XML::to_string( $problem->{problem} ),
			};

			if( defined $problem->{field} )
			{
				$problem_data->{field} = $problem->{field};
			}

			if( defined $problem->{eprint} )
			{
				$problem_data->{eprintid} = $problem->{eprint}->get_id;
				$problem_data->{edit_url} = $problem->{eprint}->get_control_url;
			}

			push @json_problems, $problem_data;
		}

		push @{$json->{data}}, { userid => $userid, citation => EPrints::XML::to_string( $frag ), problems => \@json_problems };
	});

	print $self->to_json( $json );
}



sub render_user
{
        my( $self, $user, $problems ) = @_;

	my $session = $self->{session};
	my $chunk = $session->make_doc_fragment;

        my $link = $chunk->appendChild( $session->make_element( "a",
                name => $user->value( "username" ),
        ) );
        $chunk->appendChild( $user->render_citation( "ref_support" ) );

	# perform validation checks on the data
        # to do this we'll need all the related objects which we can get by borrowing a REF Support Export plugin
        my $export_plugin = $self->{session}->plugin( "Export::REF_Support" );
        $export_plugin->{report} = $self->{processor}->{report};
        my $objects = $export_plugin->get_related_objects( $user );

        my @user_problems = $self->validate_user( $export_plugin, $objects );

	# gather problems together (under one user)
	if( scalar( @user_problems ) )
	{
		my $frag = $session->make_doc_fragment;
		
		my $c = 0;
		for( @user_problems )
		{
			if( defined $_->{field} )
			{
				push @$problems, { user => $user, problem => $_->{desc}, field => $_->{field} };
				next;
			}
			$frag->appendChild( $session->make_element( 'br' ) ) if( $c++ > 0 );
			$frag->appendChild( $_->{desc} );
		}

		push @$problems, { user => $user, problem => $frag };
	}

	my $div = $chunk->appendChild( $session->make_element( "div" ) );
	$link = $div->appendChild( $session->make_element( "a",
		name => $user->value( "username" ),
	) );

	# cf Screen::REF::Overview
        $chunk->appendChild( $user->render_citation( 'ref_support_current_staff' ) );

	return $chunk;
}

sub render_problem_row
{
	my( $self, $problem ) = @_;

        my $session = $self->{session};
        my $benchmark = $self->{processor}->{benchmark};
        my $uoa = $self->{processor}->{uoa};

        my $tr = $session->make_element( "tr" );
        my $td;

        my $link_td = $tr->appendChild( $session->make_element( "td" ) );

        my $users = $problem->{user};
        $users = [$users] if ref($users) ne "ARRAY";
        $td = $tr->appendChild( $session->make_element( "td",
                style => "white-space: nowrap",
        ) );
        foreach my $user (@$users)
        {
                $td->appendChild( $session->make_element( "br" ) )
                        if $td->hasChildNodes;
                $td->appendChild( $user->render_citation_link( "brief" ) );

                $link_td->appendChild( $session->make_text( " " ) )
                        if $link_td->hasChildNodes;
                my $link = $link_td->appendChild( $session->render_link(
                        "#".$user->value( "username" ),
                ) );
                $link->appendChild( $self->html_phrase( "view" ) );
                $link_td->appendChild( $session->make_text( "/" ) );
                $link = $link_td->appendChild( $session->render_link(
                        $self->user_control_url( $user ),
                ) );
                $link->appendChild( $self->html_phrase( "edit" ) );
        }

        $td = $tr->appendChild( $session->make_element( "td" ) );
      	$td->appendChild( $problem->{problem} );

        return $tr;
}

sub user_control_url
{
	my( $self, $user ) = @_;

	my $return_to = $self->get_id;
	$return_to =~ s/^Screen:://;

	my $href = URI->new( $self->{session}->config( "userhome" ) );
	$href->query_form(
		screen => "REF_Support::User::Edit",
		dataobj => $user->id,
		return_to => $return_to
	);

	return $href;
}

sub validate_user
{
	my( $self, $export_plugin, $objects ) = @_;

	my $f = $self->param( "validate_user" );
	return () if !defined $f;

	my @problems = &$f( @_[1..$#_], $self );

	return @problems;
}

1;
