=head1 NAME

EPrints::Plugin::Screen::REF_Support::Circ::View

=cut

package EPrints::Plugin::Screen::REF_Support::Circ::View;

@ISA = ( 'EPrints::Plugin::Screen::Workflow::View' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "ref_support_circ_item_actions",
			position => 50,
		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;

}

sub render_common_action_buttons
{
        my( $self ) = @_;

        my $datasetid = $self->{processor}->{dataset}->id;

        return $self->render_action_list_bar( ["${datasetid}_view_actions", "dataobj_view_actions"], {
                                        dataset => 'user',
                                        dataobj => $self->{processor}->{dataobj}->get_value( "userid" ),
                                } );
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

