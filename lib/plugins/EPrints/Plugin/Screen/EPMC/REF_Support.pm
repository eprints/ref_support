package EPrints::Plugin::Screen::EPMC::REF_Support;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;

sub new
{
      my( $class, %params ) = @_;

      my $self = $class->SUPER::new( %params );

      $self->{actions} = [qw( enable disable ) ];
      $self->{disable} = 0; # always enabled, even in lib/plugins

      $self->{package_name} = "ref_support";

      return $self;
}

=item $screen->action_enable( [ SKIP_RELOAD ] )

Enable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_enable
{
	my( $self, $skip_reload ) = @_;

	$self->SUPER::action_enable( $skip_reload );

	# Add the REF Support UoAs:
	$self->add_ref_uoas();

	# re-commit ref_support_selection dataset (pre-populate ref_support_selection.output_type)
	$self->recommit_ref_support_selections();

	$self->reload_config if !$skip_reload;
}

sub add_ref_uoas
{
	my( $self ) = @_;
	
	my $repo = $self->{repository};
	
	# First check that this subject tree doesn't already exist...
	my $ds = $repo->dataset( 'subject' );
	my $test_subject_id = $ds->dataobj( 'ref20nn_uoas' );

	if( !defined $test_subject_id )
	{
		my $filename = $repo->config( 'archiveroot' ).'/cfg/ref_support_uoa';
		if( -e $filename )
		{
			my $plugin = $repo->plugin( 'Import::FlatSubjects' );
			my $list = $plugin->input_file( dataset => $repo->dataset( 'subject' ), filename=>$filename );
			$repo->dataset( 'subject' )->reindex( $repo );
		}
	}
}

# Note: recommits only the current Benchmark
sub recommit_ref_support_selections
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $benchmark = EPrints::DataObj::REF_Support_Benchmark->default( $repo ) or return;

	my $list = $benchmark->selections() or return;
        
	$list->map( sub {
                my( undef, undef, $item ) = @_;
                
		$item->commit( 1 );
        } );

}

=item $screen->action_disable( [ SKIP_RELOAD ] )

Disable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_disable
{
	my( $self, $skip_reload ) = @_;

	return $self->SUPER::action_disable( $skip_reload );
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	unless( defined $self->{processor}->{dataobj} )
	{
		$self->{processor}->{dataobj} = $self->{session}->dataset( 'epm' )->dataobj( $self->{package_name} );
	}
}

1;

