=head1 NAME

EPrints::Plugin::Screen::REF_Support::User::ManageContracts

=cut

package EPrints::Plugin::Screen::REF_Support::User::ManageContracts;

use EPrints::Plugin::Screen::Listing;

@ISA = ( 'EPrints::Plugin::Screen::Listing' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
                {
                        place => "dataobj_view_actions",
                        position => 1660,
                },
                {
                        place => "ref_support_listing_user_actions",
                        position => 200
                },
        ];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $self->{session};

	my $user_ds = $session->dataset( "user" );
	my $circ_ds = $session->dataset( "ref_support_circ" );

	my $columns = $self->get_columns;
	my $filters = [$self->get_filters];
	$self->{processor}->{search} = $circ_ds->prepare_search(
                filters => $filters,
                search_fields => [
                        (map { { meta_fields => [$_->name] } } @$columns)
                ],
        );

	my $id = $session->param( "dataobj" );
	my $dataobj = $self->{processor}->{dataobj};
        $dataobj = $user_ds->dataobj( $id ) if !defined $dataobj;
        if( !defined $dataobj )
        {
                $processor->{screenid} = "Error";
                $processor->add_message( "error", $session->html_phrase(
                        "lib/history:no_such_item",
                        datasetid=>$session->make_text( "user" ),
                        objectid=>$session->make_text( $id ) ) );
                return;
        }

	$processor->{dataset} = $circ_ds;
        $processor->{dataobj} = $dataobj;
}

sub get_columns
{
	my( $self ) = @_;

	my $dataset = $self->{session}->dataset( "ref_support_circ" );
	my @fields = ();
	my $columns = [ "circ","fixed_term_start","fixed_term_end" ];
	foreach my $c ( @{$columns} ) 
	{
		push @fields, $dataset->field( $c );
	}
	return \@fields;
}

sub can_be_viewed
{
        my( $self ) = @_;

        return 0 unless( $self->{session}->config( 'ref_enabled' ) );

	return 0 unless( defined $self->{processor}->{dataset} && ( $self->{processor}->{dataset}->id eq 'user' || $self->{processor}->{dataset}->id eq 'ref_support_circ' ) );

        # sf2 - allow local over-ride of whether a user can view the REF1 Data page
        if( $self->{session}->can_call( 'ref_can_user_view_ref1' ) )
        {
                my $rc = $self->{session}->call( 'ref_can_user_view_ref1', $self->{session} ) || 0;
                return $rc;
        }

        my $role = $self->{processor}->{dataobj} || $self->{processor}->{role};

        # if called from a Workflow-type plugin, {dataobj} will be set to the "circ"
	if( ref $role eq "EPrints::DataObj::REF_Support_Circ" )
	{
		my $user_ds = $self->{session}->dataset( "user" );
		$role = $user_ds->dataobj( $role->get_value( "userid" ) );
	}

        return 0 unless( defined $role );

        my $role_uoa = $role->value( 'ref_support_uoa' );
        return 0 unless( defined $role_uoa );

        my $user = $self->{session}->current_user;

        # current_user is a champion
        if( $user->exists_and_set( 'ref_support_uoa_role' ) )
        {
                # but is he a champion for the user's uoa?
                my $uoas = $user->value( 'ref_support_uoa_role' );
                foreach( @$uoas )
                {
                        return 1 if "$_" eq "$role_uoa";
                }

                return 0;
        }

        if( $role->get_id == $user->get_id )
        {
                return $user->has_role( 'ref/edit/ref1abc' );
        }

        return 0;
}

sub render_title
{
	my( $self ) = @_;

	return $self->EPrints::Plugin::Screen::render_title();
}

sub perform_search
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $search = $processor->{search};

	my $ds = $session->dataset( 'ref_support_circ' );
	my $user = $processor->{dataobj};

	my $contracts = $ds->search( filters => [
		{ meta_fields => [ "userid" ], value => $user->id },
	]);

	return $contracts;	

}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $user = $repo->current_user;
	my $chunk = $repo->make_doc_fragment;

	$chunk->appendChild( $self->render_top_bar() );

	my $imagesurl = $repo->current_url( path => "static", "style/images" );

	### Get the items owned by the current user
	my $list = $self->perform_search;

	my $has_contracts = $list->count > 0;

	$chunk->appendChild( $self->render_action_list_bar( "manage_contracts_tools" ) );

	if( $has_contracts )
	{
		$chunk->appendChild( $self->render_contracts( $list ) );
	}

	return $chunk;
}

sub render_top_bar
{
        my( $self ) = @_;

        my $session = $self->{session};
        my $chunk = $session->make_doc_fragment;

        # we've munged the argument list below
        $chunk->appendChild( $self->render_action_list_bar( "dataobj_tools", {
                dataset => $self->{processor}->{dataset}->id,
		user => $self->{processor}->{dataobj}->id,
        } ) );

        return $chunk;
}

sub render_contracts
{
	my( $self, $list ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my $chunk = $session->make_doc_fragment;
	my $imagesurl = $session->current_url( path => "static", "style/images" );
	my $ds = $session->dataset( "ref_support_circ" );

	my $columns = [ "fixed_term_start","fixed_term_end" ];
	
	# Paginate list
	my %opts = (
		params => {
			screen => "REF_Support::User::ManageContracts",
		},
		columns => [@{$columns}, undef ],
		render_result => sub {
			my( $session, $c, $info ) = @_;

			my $class = "row_".($info->{row}%2?"b":"a");

			my $tr = $session->make_element( "div", class=>"ep_table_row $class" );

			my $first = 1;
			for( @$columns )
			{
				my $td = $session->make_element( "div", class=>"ep_table_cell ep_columns_cell".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $c->render_value( $_ ) );
			}

			$self->{processor}->{circ} = $c;
			$self->{processor}->{circid} = $c->id;
			my $td = $session->make_element( "div", class=>"ep_table_cell ep_columns_cell ep_columns_cell_last", align=>"left" );
			$tr->appendChild( $td );
			#$td->appendChild( 
			#	$self->render_action_list_icons( "circ_item_actions", { 'circid' => $self->{processor}->{circid} } ) );
			$td->appendChild( $self->render_dataobj_actions( $c ) );
			delete $self->{processor}->{circ};

			++$info->{row};

			return $tr;
		},
	);
	$chunk->appendChild( EPrints::Paginate::Columns->paginate_list( $session, "_buffer", $list, %opts ) );

	return $chunk;
}


1;


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

