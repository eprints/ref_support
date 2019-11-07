package EPrints::Plugin::Screen::REF_Support::Report::Research_Groups;

use EPrints::Plugin::Screen::REF_Support::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Report' );

use strict;

sub research_groups
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $rg_ds = $session->dataset( 'ref_support_rg' );
	my @uoas = @{ $self->{processor}->{uoas} || [] };

        my @uoa_ids = map { $_->id } @uoas;
        my $rgs = $rg_ds->search( filters => [
                { meta_fields => [ "uoa" ], value => join( " ", @uoa_ids ),},
        ]);
	return $rgs->reorder( "uoa/code" );
	return $rgs;
}

sub export
{
        my( $self, $fh, $skip_intro ) = @_;
        my $plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $plugin;
	my $rg_list = $self->research_groups;

	if( defined $fh ) # we're being called from some other context, not via the export button on the report
	{
		$plugin->output_list(
        	        list => $rg_list,
                	fh => $fh,
			benchmark => $self->{processor}->{benchmark},
			skip_intro => $skip_intro,
        	);
	}
	else # just download the report
	{
        	$plugin->initialise_fh( \*STDOUT );
	        $plugin->output_list(
        	        list => $rg_list,
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
	$self->{processor}->{report} = 'research_groups';

	$self->SUPER::properties_from;
}

sub render
{
	my( $self ) = @_;

        my $session = $self->{session};
        my @uoas = @{ $self->{processor}->{uoas} || [] };
	my $rg_ds = $session->dataset( 'ref_support_rg' );

        my $chunk = $session->make_doc_fragment;

        $chunk->appendChild( $session->html_phrase( "Plugin/Screen/REF_Support/Report:header",
                benchmark => $self->render_current_benchmark,
                export => $self->render_export_bar
        ) );

        my $table = $chunk->appendChild( $session->make_element( "table",
                style => "display: none;",
                class => "ep_ref_problems"
        ) );

	foreach my $uoa ( @uoas )
	{
		my $rgs = $rg_ds->search( filters => [
                	{ meta_fields => [ "uoa" ], value => $uoa->id,},
        	]);

		if( $rgs->count > 0 ) 
		{
			my $h3 = $chunk->appendChild( $session->make_element( 'h3', class => 'ep_ref_uoa_header' ) );
			$h3->appendChild( $uoa->render_description );


			$rgs->map( sub {
				my( $session, undef, $rg ) = @_;
				my $div = $chunk->appendChild( $session->make_element( "div", class => "ep_ref_report_box" ) );
				$div->appendChild( $self->render_rg( $rg ) );	
			} );
		}
	}

	return $chunk;
}

sub render_rg
{
	my( $self, $rg ) = @_;

	my $session = $self->{session};
        my $chunk = $session->make_doc_fragment;

	my $div = $chunk->appendChild( $session->make_element( "div", class => "ep_ref_user_citation" ) );
	$div->appendChild( $rg->render_citation( "brief" ) );

	$div = $chunk->appendChild( $session->make_element( "div" ) );
	my $table = $div->appendChild( $session->make_element( "table" ) );	

	my @rg_problems = $self->validate_rg( $rg );

	my @table_cells;
	push @table_cells, $session->make_text( $rg->value( "code" ) );

	# is there a problem with this rg's id?
	if( scalar @rg_problems )
	{
		for( @rg_problems )
		{
			my $warning_div = $session->make_element( "div", class => "ep_ref_report_user_problems" );
			$warning_div->appendChild( $_ );
			push @table_cells, $warning_div;
		}
	}
	
	$table->appendChild( $session->render_row( $self->html_phrase( "research_group:code" ), @table_cells ) );

	return $chunk;
}

sub validate_rg
{
        my( $self, $rg ) = @_;
	
	my $session = $self->{session};

	my @problems;

	# is there a code??
	my $code = $rg->get_value( "code" );
	if( !EPrints::Utils::is_set( $code ) )
	{
		push @problems, $self->html_phrase( "research_group:no_code" );
		return @problems;
	}

	# is there a name??
	my $name = $rg->get_value( "name" );
	if( !EPrints::Utils::is_set( $name ) )
	{
		push @problems, $self->html_phrase( "research_group:no_name" );
		return @problems;
	}

	# is the code more than a single alphanumeric character
	if( $rg->get_value( "code" ) !~ m/^[a-zA-Z0-9]$/ )
	{
		push @problems, $self->html_phrase( "research_group:invalid_length" );
	}

	# are there any duplicate codes within this UoA
	# this approach is probably a bit inefficient, but this is unlikely to be a huge dataset so it should be ok...
	my $rg_ds = $session->dataset( 'ref_support_rg' );
	my $rgs = $rg_ds->search( filters => [
        	{ meta_fields => [ "uoa" ], value => $rg->get_value( "uoa" ) },
        ]);

	my @uoa_codes;
        $rgs->map( sub {
		my( $session, undef, $other_rg ) = @_;
		push @uoa_codes, $other_rg->get_value( "code" ) unless $rg->id == $other_rg->id;
	} );
	
	if( grep { $rg->get_value( "code" ) eq $_ } @uoa_codes )
	{
		push @problems, $self->html_phrase( "research_group:duplicate_code" );
	}

	# is the name too long?
	if( length( $name ) > 128 )
	{
		push @problems, $self->html_phrase( "research_group:name_length" );
	} 	

        return @problems;
}

1;
