package EPrints::Plugin::Screen::REF_Support::Circ::Destroy;

use EPrints::Plugin::Screen::REF_Support::Circ;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Circ' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ remove cancel /];

	$self->{icon} = "action_remove.png";

	$self->{appears} = [
		{
			place => "ref_support_circ_item_actions",
			position => 200,
		},
	];
	
	return $self;
}

sub properties_from
{
        my( $self ) = @_;

        my $session = $self->{session};

        $self->SUPER::properties_from;
	
	$self->{processor}->{dataset} = $session->dataset( 'ref_support_circ' );
        $self->{processor}->{circ} = $session->dataset( 'ref_support_circ' )->dataobj( $session->param( 'dataobj' ) ); 
}


sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	unless( defined $self->{processor}->{circ} )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "no_such_item" ) );

		my %buttons = (
			cancel => $self->{session}->phrase(
					"lib/submissionform:action_cancel" ),
		);
		
		my $form= $self->render_form;
		$form->appendChild( 
			$self->{session}->render_action_buttons( 
				%buttons ) );
		$div->appendChild( $form );

		return( $div );
	}
	
	$div->appendChild( $self->html_phrase("sure_delete",
		title=>$self->{processor}->{circ}->render_citation() ) );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		remove => $self->{session}->phrase(
				"lib/submissionform:action_remove" ),
		_order => [ "remove", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub hidden_bits
{
        my( $self ) = @_;

        return screen => $self->{processor}->{screenid}, dataobj => $self->param( 'dataobj' );
}

sub allow_cancel { return shift->can_be_viewed }
sub allow_remove { return shift->can_be_viewed }

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "REF_Support::Circ::View";
	$self->{processor}->{dataobj} = $self->{processor}->{circ};
}

sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "REF_Support::Overview";
	$self->{processor}->{dataset} = $self->{session}->dataset( 'ref_support_circ' ) unless( defined $self->{processor}->{dataset} );

	$self->properties_from;

	if( !$self->{processor}->{circ}->remove )
	{
		$self->{processor}->add_message( "message", $self->html_phrase( "item_not_removed" ) );
		$self->{processor}->{screenid} = "Workflow::View";
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) );
}

1;
