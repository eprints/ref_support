package EPrints::Plugin::Screen::REF_Support::Edit;

# Modifies a REF Selection object

use EPrints::Plugin::Screen::REF_Support;

@ISA = ( 'EPrints::Plugin::Screen::REF_Support' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	return $self;
}

sub can_be_viewed 
{
        my( $self ) = @_;

        my $rc = $self->EPrints::Plugin::Screen::REF_Support::can_be_viewed;
        return 0 if( !defined $rc || !$rc );

	my $selection = $self->{processor}->{selection};
        my $selection_uoa = $selection->uoa( $self->current_benchmark );
	
	# is this my selection
	if( $selection_uoa eq $self->{session}->current_user->value( 'ref_support_uoa' ) && $selection->value( "user_id" ) eq $self->{session}->current_user->id )
        {
                return 1;
        }

	#if current user is a champion....are they the right champion for this selection
	if( $self->{session}->current_user->exists_and_set( 'ref_support_uoa_role' ) )
	{
		my $uoas = $self->{session}->current_user->value( 'ref_support_uoa_role' );
		my $selection = $self->{processor}->{selection};
		my $selection_uoa = $selection->uoa( $self->current_benchmark );
		my $seen = 0;
		if( grep { $selection_uoa eq $_ } @{$uoas} )
		{
			return 1;
		}	
	}
	return 0;
}

sub from
{
	my( $self ) = @_;

	if( defined $self->{processor}->{internal} )
	{
		my $from_ok = $self->workflow->update_from_form( $self->{processor},undef,1 );
		$self->uncache_workflow;
		return unless $from_ok;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub allow_stop
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_stop
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = $self->screen_after_flow;
}	


sub allow_save
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_save
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;

	$self->{processor}->{screenid} = $self->screen_after_flow;

	my $warnings = $self->{processor}->{selection}->get_warnings;
        if( scalar @{$warnings} > 0 )
        {
                my $dom_warnings = $self->{session}->make_element( "ul" );
                foreach my $warning_xhtml ( @{$warnings} )
                {
                        my $li = $self->{session}->make_element( "li" );
                        $li->appendChild( $warning_xhtml );
                        $dom_warnings->appendChild( $li );
                }
                $self->workflow->link_problem_xhtml( $dom_warnings, "EPrint::Edit" );
                $self->{processor}->add_message( "warning", $dom_warnings );
        }

}


sub allow_prev
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}
	
sub action_prev
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;
	$self->workflow->prev;
}


sub allow_next
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_next
{
	my( $self ) = @_;

	my $from_ok = $self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;
	return unless $from_ok;

	if( !defined $self->workflow->get_next_stage_id )
	{
		$self->{processor}->{screenid} = $self->screen_after_flow;
		return;
	}

	$self->workflow->next;
}

sub screen_after_flow
{
	my( $self ) = @_;

	return "REF_Support::Listing";
}

sub render_title
{
	my( $self ) = @_;

	my $selection = $self->{processor}->{selection};

	return $self->html_phrase( 'title' ) unless( defined $selection );

	my $epfield = $selection->dataset->field( 'eprint' );
	my $eprint = $epfield->dataobj( $selection->value( 'eprint' ) );
	
	return $self->html_phrase( 'title' ) unless( defined $eprint );

	return $self->html_phrase( 'eprint_title', title => $eprint->render_value( 'title' ) );
}

sub render
{
	my( $self ) = @_;

	my $form = $self->render_form;

	$form->appendChild( $self->render_buttons );
	$form->appendChild( $self->workflow->render );
	$form->appendChild( $self->render_buttons );
	
	return $form;
}


sub render_buttons
{
	my( $self ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	if( defined $self->workflow->get_prev_stage_id )
	{
		push @{$buttons{_order}}, "prev";
		$buttons{prev} = $self->phrase( "prev" );
	}

	push @{$buttons{_order}}, "stop", "save";
	$buttons{stop} = $self->phrase( "stop" );
	$buttons{save} = $self->phrase( "save" );

	if( defined $self->workflow->get_next_stage_id )
	{
		push @{$buttons{_order}}, "next";
		$buttons{next} = $self->phrase( "next" );
	}	
	return $self->{session}->render_action_buttons( %buttons );
}

sub workflow
{
        my( $self, $staff ) = @_;

        my $cache_id = "workflow";
        $cache_id.= "_staff" if( $staff );

	my $session =  $self->{session};
	my $is_uoa_champion = $session->current_user->exists_and_set( 'ref_support_uoa_role' );
        if( !defined $self->{processor}->{$cache_id} )
        {
                my %opts = (
                        item => $self->{processor}->{selection},
                        session => $self->{session} );
                $opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
		$opts{IS_CHAMPION} = [$is_uoa_champion ? "TRUE" : "FALSE","BOOLEAN"];
                $self->{processor}->{$cache_id} = EPrints::Workflow->new(
                        $self->{session},
                        "default",
                        %opts );
        }

        return $self->{processor}->{$cache_id};
}

sub uncache_workflow
{
        my( $self ) = @_;

        delete $self->{processor}->{workflow};
        delete $self->{processor}->{workflow_staff};
}

sub properties_from
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{dataset} = $self->{session}->dataset( "ref_support_selection" );

	my $selectionid = $self->{session}->param( "selectionid" );
	$self->{processor}->{selectionid} = $selectionid;
	$self->{processor}->{selection} = $dataset->dataobj( $selectionid );

	if( !defined $self->{processor}->{selection} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error",
				$self->html_phrase(
					"no_such_selection",
					id => $self->{session}->make_text(
						$self->{processor}->{selectionid} ) ) );
		return;
	}

}

sub redirect_to_me_url
{
        my( $self ) = @_;

        return $self->SUPER::redirect_to_me_url."&selectionid=".$self->{processor}->{selectionid};
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		selectionid => $self->{processor}->{selectionid},
	);
}

1;


