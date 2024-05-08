package EPrints::Plugin::Screen::REF_Support::Report::Former_Staff_Contracts;

use EPrints::Plugin::Screen::REF_Support::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Report' );

use strict;

sub export
{
        my( $self, $fh, $skip_intro ) = @_;
        my $plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $plugin;

	my $contracts = $self->get_contracts;
	
	# send a list of contracts to be exported
	if( defined $fh )
	{
                $plugin->output_list(
                        list => $contracts,
                        fh => $fh,
                        benchmark => $self->{processor}->{benchmark},
			skip_intro => $skip_intro,
                );
	}
	else
	{	
        	$plugin->initialise_fh( \*STDOUT );
	        $plugin->output_list(
        	        list => $contracts,
                	fh => \*STDOUT,
			benchmark => $self->{processor}->{benchmark},
			skip_intro => $skip_intro,
        	);
	}
}

sub get_contracts
{
	my( $self ) = @_;

	my $session = $self->{session};
        my $contracts_ds = $session->dataset( "ref_support_circ" );

        my @ids = ();

        # get contracts from our users
        my $contracts = EPrints::List->new( repository => $session, dataset => $contracts_ds, ids => \@ids );
        my $users = $self->users;
        $users->map( sub {
                my( undef, undef, $user ) = @_;
                my $user_contracts = EPrints::DataObj::REF_Support_Circ->search_by_user( $session, $user );
                $contracts = $contracts->union( $user_contracts );
        } );
		
	return $contracts;
}

sub properties_from
{
	my( $self ) = @_;

	# will be used by the SUPER class:
	$self->{processor}->{report} = 'ref1_former_staff_contracts';

	$self->SUPER::properties_from;
}

# returns the users belonging to the selected UoA's with an endDate before 31 July 2020
sub users_by_uoa
{
        my( $self ) = @_;

        my @uoas = @{ $self->{processor}->{uoas} || [] };

        my @uoa_ids = map { $_->id } @uoas;

        my $users = $self->{session}->dataset( 'user' )->search( filters => [
                { meta_fields => [ "ref_support_uoa" ], value => join( " ", @uoa_ids ),},
		{ meta_fields => [ "ref_end_date" ], value => '-2020-07-31', match => "IN" },
        ]);

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

			if( defined $problem->{ref_support_circ} )
			{
				$problem_data->{eprintid} = $problem->{ref_support_circ}->get_id;
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

	my $div = $chunk->appendChild( $session->make_element( "div" ) );
	$link = $div->appendChild( $session->make_element( "a",
		name => $user->value( "username" ),
	) );
 

	my $export_plugin = $self->{session}->plugin( "Export::REF_Support" );
        $export_plugin->{report} = $self->{processor}->{report};

	my $circs = EPrints::DataObj::REF_Support_Circ->search_by_user( $session, $user );
	$circs->map(sub {
                (undef, undef, my $circ) = @_;
	
		# display contract title (i.e. start and end date of contract)
		$chunk->appendChild( $circ->render_citation( 'ref1_former_staff_contracts' ) );	

		# get and display contract problems
		my $objects = $export_plugin->get_related_objects( $circ );
		push @$problems, $self->validate_circ( $export_plugin, $objects );
	} );
	
	return $chunk;
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

sub validate_circ
{
	my( $self, $export_plugin, $objects ) = @_;

	my $f = $self->param( "validate_circ" );
	return () if !defined $f;

	my @problems = &$f( @_[1..$#_], $self );

	if( @problems == 0 )
        {
                return ();
        }
        else
        {
                my $frag = $self->{session}->make_doc_fragment;
                foreach my $problem (@problems)
                {
                        my $p = $frag->appendChild( $self->{session}->make_element( 'p' ) );
                        $p->appendChild( $problem->{desc} );
                }
                $objects->{problem} = $frag;
                return $objects;
        }
}

1;
