package EPrints::Plugin::Screen::REF_Support::Research_Group::Edit;

use EPrints::Plugin::Screen::Workflow::Edit;
use EPrints::Plugin::Screen::REF_Support;

@ISA = qw(
	EPrints::Plugin::Screen::Workflow::Edit
        EPrints::Plugin::Screen::REF_Support
);

use strict;

sub new
{
        my( $class, %params ) = @_;

        my $self = $class->SUPER::new(%params);

        $self->{appears} = [];

        return $self;
}

sub action_save
{
        my( $self ) = @_;

        $self->workflow->update_from_form( $self->{processor} );
        $self->uncache_workflow;

        my $return_to = $self->repository->param('return_to');
        if ($return_to)
        {
                $self->{processor}->{screenid} = $return_to;
        }
        else
        {
                $self->{processor}->{screenid} = $self->view_screen;
        }
}


1;
