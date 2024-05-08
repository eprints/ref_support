package EPrints::Plugin::Screen::REF_Support::Circ::New;

use EPrints::Plugin::Screen::REF_Support::Circ;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Circ' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create /];

	my $actions_appear = [
		{
			place => "dataobj_tools",
			position => 100,
			action => "create",
		},
	];

	$self->{appears} = $actions_appear;

	return $self;
}

sub properties_from
{
	my( $self ) = @_;
	
	my $processor = $self->{processor};
	my $session = $self->{session};

	my $datasetid = "ref_support_circ";

	my $dataset = $session->dataset( $datasetid );
	if( !defined $dataset )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $session->html_phrase(
			"lib/history:no_such_item",
			datasetid=>$session->make_text( $datasetid ),
			objectid=>$session->make_text( "" ) ) );
		return;
	}

	$processor->{dataset} = $dataset;

	# get the user we're making this new circ/contract for
	my $user_ds = $session->dataset( "user" );
	my $id = $session->param( "user" );
        my $user = $user_ds->dataobj( $id );
        if( !defined $user )
        {
                $processor->{screenid} = "Error";
                $processor->add_message( "error", $session->html_phrase(
                        "lib/history:no_such_item",
                        datasetid=>$session->make_text( "user" ),
                        objectid=>$session->make_text( $id ) ) );
                return;
        }
	$processor->{user} = $user;

	$self->SUPER::properties_from;
}

sub allow_create
{
	my ( $self ) = @_;

	return $self->can_be_viewed();
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{dataset};

	my $epdata = {};

	if( defined $ds->field( "userid" ) )
	{
		my $user = $self->{processor}->{user};
		$epdata->{userid} = $user->id;
	}

	$self->{processor}->{dataobj} = $ds->create_dataobj( $epdata );

	if( !defined $self->{processor}->{dataobj} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message(
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}
	
	$self->{processor}->{screenid} = "REF_Support::Circ::Edit";
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $self->html_phrase( 'create_warning') );

	$chunk->appendChild( $self->render_action_list_bar( "ref_support_circ_create" ) );

	return $chunk;
}


1;
