package EPrints::Plugin::Export::REF_Support::REF_JSON;

# HEFCE Generic Exporter to JSON

use EPrints::Plugin::Export::REF_Support;
@ISA = ( "EPrints::Plugin::Export::REF_Support" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF Support - JSON";
	$self->{suffix} = ".json";
	$self->{mimetype} = "application/json";
        $self->{advertise} = $self->{enable} = EPrints::Utils::require_if_exists( "HTML::Entities" ) ? 1:0;
        $self->{accept} = [ 'report/submission' ]; # only allowed for the complete report


	return $self;
}

1;
