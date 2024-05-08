package EPrints::Plugin::Screen::REF_Support::Circ;

use EPrints::Plugin::Screen::REF_Support;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support' );

use strict;

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

1;
