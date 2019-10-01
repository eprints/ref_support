package EPrints::Plugin::Screen::REF_Support::Report::Research_Groups;

use EPrints::Plugin::Screen::REF_Support::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Report' );

use strict;

# No UoAs required to see this role, but we do still insist users are a UoA Champion
sub can_be_viewed
{
        my( $self ) = @_;

        return 0 unless( $self->{session}->config( 'ref_enabled' ) );

        my $user = $self->{processor}->{user};
        return 0 if !defined $user;

	if( $user->is_set( 'ref_support_uoa_role' ) )
	{
		return 1;
	}

	return 0;
}

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

	return $rgs;
}

sub export
{
        my( $self ) = @_;

        my $plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $plugin;

	my $rg_list = $self->research_groups;

        $plugin->initialise_fh( \*STDOUT );
        $plugin->output_list(
                list => $rg_list,
                fh => \*STDOUT,
		benchmark => $self->{processor}->{benchmark},
        );
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

        my $chunk = $session->make_doc_fragment;

        $chunk->appendChild( $session->html_phrase( "Plugin/Screen/REF_Support/Report:header",
                benchmark => $self->render_current_benchmark,
                export => $self->render_export_bar
        ) );

        my $table = $chunk->appendChild( $session->make_element( "table",
                style => "display: none;",
                class => "ep_ref_problems"
        ) );

	my $rgs = $self->research_groups;
        my $rg_ids = $rgs->ids;

	my $h3 = $chunk->appendChild( $session->make_element( 'h3', class => 'ep_ref_uoa_header' ) );
	#$h3->appendChild( );

	$rgs->map( sub {

		my( $session, undef, $rg ) = @_;
		my $div = $chunk->appendChild( $session->make_element( "div", class => "ep_ref_report_box" ) );
		$div->appendChild( $self->render_rg( $rg ) );	
	} );

	return $chunk;
}

sub render_rg
{
	my( $self, $rg ) = @_;

	my $session = $self->{session};
        my $chunk = $session->make_doc_fragment;

	my $div = $chunk->appendChild( $session->make_element( "div", class => "ep_ref_user_citation" ) );
	$div->appendChild( $rg->render_citation );

	$div = $chunk->appendChild( $session->make_element( "div" ) );
	my $table = $div->appendChild( $session->make_element( "table" ) );	

	my @table_cells;
	push @table_cells, $session->make_text( $rg->id );

	# is there a problem with this rg's id?
	if( $rg->get_value( "code" ) !~ m/^[a-zA-Z0-9]$/ )
	{
		my $warning_div = $session->make_element( "div", class => "ep_ref_report_user_problems" );
		$warning_div->appendChild( $self->html_phrase( "research_group:invalid_length" ) );
		push @table_cells, $warning_div;
	}

	$table->appendChild( $session->render_row( $self->html_phrase( "research_group:id" ), @table_cells ) );

	return $chunk;
}

1;
