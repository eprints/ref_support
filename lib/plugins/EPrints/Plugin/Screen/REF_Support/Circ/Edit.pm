package EPrints::Plugin::Screen::REF_Support::Circ::Edit;

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

        $self->{appears} = [
                {
                        place => "ref_support_circ_item_actions",
                        position => 100,
                },
        ];

        return $self;
}

sub can_be_viewed
{
        my( $self ) = @_;

        return 0 if !$self->has_workflow();

	return 1;
}

sub action_stop
{
        my( $self ) = @_;

        $self->{processor}->{screenid} = "REF_Support::Circ::View";
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
		$self->{processor}->{screenid} = "REF_Support::Circ::View";

		# send back to the circ's users manage contracts screen
                #$self->{processor}->{screenid} = "REF_Support::User::ManageContracts";
		#my $user_ds = $self->{session}->dataset( 'user' );
		#my $circ = $self->dataobj;
		#my $userid = $circ->get_value( "userid" );	
		#print STDERR "userid.....$userid\n";
		#my $user = $user_ds->dataobj( $userid );
		#$self->{processor}->{dataset} = $self->{session}->dataset( 'user' );
		#$self->{processor}->{dataobj} = $user;
		#print STDERR "user....$user\n"
        }
}


1;
