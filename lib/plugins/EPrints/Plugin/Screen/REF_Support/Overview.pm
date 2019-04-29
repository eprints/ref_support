package EPrints::Plugin::Screen::REF_Support::Overview;

use EPrints::Plugin::Screen::REF_Support;

@ISA = qw(
	EPrints::Plugin::Screen::REF_Support
);

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{appears} = [
		{
			place => "key_tools",
			position => 1100,
		},
	];

	$self->{stime} = time();

	return $self;
}

sub can_be_viewed 
{
	my( $self ) = @_;

	return 0 unless( $self->{session}->config( 'ref_enabled' ) && defined $self->{session}->current_user );

	#only applicable for admins or users with a ref role
	if( $self->{session}->current_user->has_role( "admin" ) || $self->{session}->current_user->has_role( "ref/view/ref2" ) )
	{
		my $state = 0; #stores the state of ref_support
		$state = "no_uoa" unless( $self->{session}->current_user->exists_and_set( 'ref_support_uoa' ) || $self->{session}->current_user->exists_and_set( 'ref_support_uoa_role' ) );

		$state = "no_benchmark" if !defined $self->current_benchmark;

		$self->{processor}->{state} = $state;

		if( $state && !$self->{session}->current_user->has_role( "admin" )) #there are issues and we're not an admin, so don't show
		{
			return 0;
		}		

		return 1;
	}
	else
	{
		return 0;
	}
}

sub wishes_to_export { shift->{session}->param( "ajax" ) }
sub export_mimetype { "text/html; charset=utf-8" }

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{dataset} = $self->{session}->dataset( "ref_support_selection" );
	
	$self->SUPER::properties_from;
}

sub render_selections
{
	my( $self, $show_actions ) = @_;

	$show_actions = 1 unless( defined $show_actions );

	my $repo = $self->{session};
	my $processor = $self->{processor};
	my $dataset = $processor->{dataset};
	my $role = $processor->{role};
	my $user = $repo->current_user;
	my $benchmark = $self->{processor}->{benchmark};

	my $selections = $benchmark->user_selections( $role );
	return $repo->html_phrase( "ref/select:none_selected" )
		if $selections->count == 0;

	my $table = $repo->make_element( "table", class=>"ref_current_selections" );

	# first need to find out any "reserved" outputs, format of the hash above is $reserved_id => $double_weighted_id
	my $reserves = {};
	$selections->map(sub {
		my( undef, undef, $selection ) = @_;

		if( $selection->is_set( 'reserve' ) )
		{
			$reserves->{$selection->get_value( 'reserve' )} = $selection->get_id;
		}
	} );

	my $n = 1;
	$selections->map(sub {
		my( undef, undef, $selection ) = @_;

		my $eprintid = $selection->value( 'eprint_id' );
		my $eprint = $repo->dataset( "eprint" )->dataobj( $eprintid );

		# this is to flag whether the eprint object exists or not:
		my $eprint_exists = 1;
		if( !defined $eprint )
		{
			$eprint = $repo->dataset( "eprint" )->make_object( $repo, { eprintid => $eprintid, eprint_status => 'inbox' } );
			$eprint_exists = 0;
		}

		my @names;
		my $others = $repo->make_doc_fragment;
		$benchmark->eprint_selections( $eprint )->map(sub {
			my( undef, undef, $other ) = @_;

			my $user_id = $other->value( "user_id" );
			if( $user_id == $role->id )
			{
				return;
			}

			my $user = $repo->user( $user_id );
			if( defined $user )
			{
				push @names, EPrints::Utils::tree_to_utf8( $user->render_description );
			} 
			else 
			{
				push @names, $repo->phrase( "ref:unknown_user", id => $user_id );
			}
		}) if( $eprint_exists );

		if( scalar( @names ) > 0 )
		{
			$others->appendChild( $repo->html_phrase( 'ref/select:also_selected_by',
						names => $repo->make_text( join(", ", @names) ) ) );
		}

		my $uoaid = $selection->uoa( $benchmark );
		my $uoa = $repo->dataset( "subject" )->dataobj( $uoaid );
		if( !defined $uoa )
		{
			$uoa = $repo->dataset( "subject" )->make_object( $repo,
				{ subjectid => $uoaid }
			);
		}

		my $actions = $repo->make_element( "ul",
			style => "margin: 0 0; padding: 0 0; list-style-type: none;",
		);

		if( $self->can_select && $show_actions )
		{
			my $li = $repo->make_element( "li" );
			$actions->appendChild( $li );
			my $uri = URI->new( $repo->current_url( query => 1 ) );
			$uri->query_form(
				screen => $self->{processor}->{screenid},
				selection => $selection->id,
				role => $role->id,
				_action_unselect => 1,
				params => $uri->query,
			);
			my $link = $repo->render_link( "$uri" );
			$link->appendChild( $repo->html_phrase( "ref/select:remove_button" ) );
			$li->appendChild( $link );

			# edit selection
			$li = $repo->make_element( "li" );
			$actions->appendChild( $li );
			$link = $repo->render_link( $selection->get_control_url );
			$link->appendChild( $repo->html_phrase( "ref/select:qualify_button" ) );
			$li->appendChild( $link );

			# synchronise UoA
			if( $uoa->id ne $role->value( "ref_support_uoa" ) )
			{
				$uri = URI->new( $repo->current_url( query => 1 ) );
				$uri->query_form(
					screen => $self->{processor}->{screenid},
					selection => $selection->id,
					role => $role->id,
					_action_sync => 1,
					params => $uri->query,
				);
				$li = $repo->make_element( "li" );
				$actions->appendChild( $li );
				$link = $repo->render_link( "$uri" );
				$link->appendChild( $self->html_phrase( "action:sync:title" ) );
				$li->appendChild( $link );
			}
		}

		my $is_reserve = $repo->make_doc_fragment;
		if( $reserves->{$selection->get_id} )
		{
			$is_reserve = $self->html_phrase( "reserved", "for" => $repo->make_text( $reserves->{$selection->get_id} ) )
		}

		$table->appendChild( $selection->render_citation( 'action',
					n => [ $n++, 'INTEGER' ],
					actions => [ $actions, 'XHTML' ],
					others => [ $others, 'XHTML' ],
					eprint_exists => [ $eprint_exists, 'BOOLEAN' ],
					is_reserve => [ $is_reserve, 'XHTML' ]
					) );
	});

	return $table;
}


sub available_reports
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;
	my $is_uoa_champion = $user->exists_and_set( 'ref_support_uoa_role' );

	my %removed_roles;

	# UoA Champion can always view all the reports
	my $role = $self->{processor}->{role};

	my @reports;
	foreach my $report ( 'ref2', 'ref1a', 'ref1b', 'ref1c' )
	{
		if( !$is_uoa_champion )
		{
			next unless( $user->has_role( "ref/view/$report" ) );
		}

		if( $report eq 'ref1c' )
		{
			# not relevant if the staff isn't Category C
			my $cat = $role->value( 'ref_category' );
			next unless( defined $cat && $cat eq 'C' );
		}

		push @reports, $report;
	}

	return \@reports;
}

sub render_report
{
	my( $self, $report, $circ ) = @_;

	if( $report eq 'ref1a' )
	{
		my $inserts = {	user_fields => $self->{processor}->{role}->render_citation( 'ref_support_ref1a' ) };

		return $circ->render_citation( 'ref1a',
			pindata => { inserts => $inserts } );

	}
	elsif( $report eq 'ref1b' || $report eq 'ref1c' )
	{
		return $circ->render_citation( $report );
	}
	elsif( $report eq 'ref2' )
	{
		return $self->render_selections( 0 );
	}	

	return $self->{session}->make_doc_fragment;
}


# Helper user actions (e.g. Edit circumstances, REF info)
sub render_user_actions
{
        my( $self ) = @_;

        my $frag;
        {
                local $self->{processor}->{dataset} = $self->{session}->dataset( 'user' );
                $frag = $self->render_action_list_bar( "ref_support_listing_user_actions", { 
				dataobj => $self->{processor}->{role}->get_id, 
				dataset => $self->{processor}->{dataset}->id,
				return_to => "REF_Support::Overview", 
		} );

                if( $frag->getElementsByTagName( 'input' ) )
                {
                        return $self->html_phrase( 'user_actions', actions => $frag );
                }
        }

        return $frag;
}


# sf2 - render(): 
# if no current benchmark exists -> render a message (saying there's nothing to select against)
# if a benchmark exists -> render the selections + the name of the benchmark + the search form
sub render
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $frag = $repo->make_doc_fragment;
	my $role = $self->{processor}->{role};
	my $state = $self->{processor}->{state};

	if( $state )
	{
		$self->{processor}->add_message( "warning", $self->html_phrase( $state ) );
		if( $state eq "no_benchmark" )
		{
			$frag->appendChild( $repo->html_phrase( 'Plugin/Screen/REF_Support/Benchmark/New:create_warning') );

		        my $action_frag = $self->render_action_list_bar( "ref_support_overview_benchmark", {
				return_to => "REF_Support::Overview",
			} );

			$frag->appendChild( $self->html_phrase( 'user_actions', actions => $action_frag ) );	
		}	
		elsif( $state eq "no_uoa" )
		{
			$frag->appendChild( $self->html_phrase( 'uoa_help') );

			my $action_frag;
	 	        local $self->{processor}->{dataset} = $self->{session}->dataset( 'user' );
                	$action_frag = $self->render_action_list_bar( "ref_support_listing_user_actions", { 
				dataobj => $self->{processor}->{role}->get_id, 
				dataset => $self->{processor}->{dataset}->id,
				return_to => "REF_Support::Overview", 
			} );

	                if( $action_frag->getElementsByTagName( 'input' ) )
        	        {
                	       $frag->appendChild( $self->html_phrase( 'user_actions', actions => $action_frag ) );
	                }
	
			$frag->appendChild( $self->html_phrase( 'uoa_champion_help') );
		}
	}
	else
	{
	        # sf2 / Placeholder phrase (empty by default, useful for Admins if they need
        	# to address the users)
	        $frag->appendChild( $self->html_phrase( 'message' ) );

		my $is_uoa_champion = $repo->current_user->exists_and_set( 'ref_support_uoa_role' );

	        if( $is_uoa_champion )
        	{
	               	$frag->appendChild( $repo->html_phrase( 'ref:top_tools:champion',
	                        tools => $self->render_tools,
        	                benchmarks => $self->render_benchmarks( "ref:benchmarks_tools" ),
                	        roles => $self->render_roles
	                ) );
        	}
	        else
        	{
			$frag->appendChild( $repo->html_phrase( 'ref:researcher:help' ) );
                	$frag->appendChild( $repo->html_phrase( 'ref:top_tools:researcher',
	                        benchmark => $self->{processor}->{benchmark}->render_citation,
        	                benchmarks => $self->render_benchmarks( "ref:benchmarks_tools:researcher" )
                	) );
	        }

	        if( $self->current_benchmark->value( "default" ) ne "TRUE" )
        	{
        	        $frag->appendChild( $self->{session}->render_message( 'warning', $self->html_phrase( 'user_cannot_select:benchmark_closed' ) ) );
	        }

		$frag->appendChild( $repo->make_element( 'br' ) );
		$frag->appendChild( $role->render_citation( 'ref_support' ) );
		$frag->appendChild( $repo->make_element( 'br' ) );

		if( !$self->{session}->current_user->has_role( "ref/select" ) )
		{
			if( $is_uoa_champion )
			{
				$frag->appendChild( $repo->html_phrase( "ref:champion_no_select:help" ) );
			}
			else
			{
				$frag->appendChild( $repo->html_phrase( "ref:researcher_no_select:help" ) );
			}
		}

		$frag->appendChild( $self->render_user_actions );

		# if the current_user is a champion
		# AND 
		# he/she's not affiliated to a UoA (cannot select for him/herself)
		# AND 
		# there are no users in the uoa he/she's champion of
		# THEN
		# display nothing!

		if( $is_uoa_champion && !$self->user_roles( $repo->current_user )->count && !$repo->current_user->exists_and_set( 'ref_support_uoa' ) )
		{
			$frag->appendChild( $self->html_phrase( 'error:nothing_to_show' ) );
			return $frag;
		}


		my $circ = EPrints::DataObj::REF_Support_Circ->new_from_user( $repo, $role->get_id, 1);

	        my @labels;
	        my @contents;
	
		my $reports = $self->available_reports;
	
		unless( scalar( @$reports ) ) 
		{
			$frag->appendChild( $self->html_phrase( 'no_reports' ) );
			return $frag; 
		}

		foreach my $report ( @$reports )
	        {
			push @labels, $repo->html_phrase( "ref:report:$report" );
			push @contents, $self->render_report( $report, $circ );
        	}


	        $frag->appendChild( $repo->xhtml->tabs(
        	        \@labels,
                	\@contents,
	                basename => 'ref_user_overview',
        	        current => 0,
	        ) );
	}
	
	return $frag;
}

1;
