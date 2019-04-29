#
# EPrints Services - REF Package
#
# Version: 1.3
#

# REF Benchmark Dataset definition

$c->{datasets}->{ref_support_benchmark} = {
	class => "EPrints::DataObj::REF_Support_Benchmark",
	sqlname => "ref_support_benchmark",
	datestamp => "date",
	index => 1,
	columns => [ 'title', 'date', 'end_date', 'default', 'description' ],
};

# REF Benchmark Fields definition

unshift @{$c->{fields}->{ref_support_benchmark}},
	{ name=>"ref_support_benchmarkid", type=>"counter", sql_counter=>"ref_support_benchmarkid", },
	{ name=>"title", type=>"text", required=>1, },
	{ name=>"date", type=>"date", },
	{ name=>"end_date", type=>"date" },
	{ name=>"userid", type=>"itemref", required=>1, datasetid=>"user"},	# sf2 - owner/creator of that benchmark
	{ name=>"description", type=>"longtext"},
	{ name=>"default", type=>"boolean"},					# sf2 - is this the default exercise?
;

# REF Benchmark Roles and attribution of Roles

# sf2 - using 'create_new' instead of 'create' to use our own Create plugin
# sf2 - 'copy' i.e. use as template
push @{$c->{user_roles}->{admin}}, qw{
	+ref_support_benchmark/details
	+ref_support_benchmark/edit
	+ref_support_benchmark/view
	+ref_support_benchmark/create_new
	+ref_support_benchmark/copy
	+ref_support_benchmark/select_current
	+ref_support_benchmark/delete
};

# REF Benchmark Module

{
package EPrints::DataObj::REF_Support_Benchmark;

our @ISA = qw( EPrints::DataObj );

sub get_dataset_id { "ref_support_benchmark" }

sub control_url { $_[0]->{session}->config( "userhome" )."?screen=REF_Support::Edit&ref_support_benchmarkid=".$_[0]->id }

sub get_defaults
{
        my( $class, $session, $data ) = @_;

        if( !defined $data->{ref_support_benchmarkid} )
        {
                $data->{ref_support_benchmarkid} = $session->get_database->counter_next( "ref_support_benchmarkid" );
        }

	if( !defined $data->{date} )
	{
		$data->{date} = EPrints::Time::get_iso_timestamp(); 
	}

	if( !defined $data->{default} )
	{
		# if this is the 1st Benchmark, set it straight as the Default Benchmark
		if( $session->dataset( $class->get_dataset_id )->search()->count > 0 )
		{
			$data->{default} = 'FALSE';
		}
		else
		{
			$data->{default} = 'TRUE';
		}
	}

        return $data;
}

=item EPrints::DataObj::REF_Support_Benchmark::select_as_default( $session, $benchmarkid );

Select the provided $benchmarkid as the Default Benchmark (the one that will be used to make selections against)

=cut
sub select_as_default
{
	my( $session, $id ) = @_;

	my $search = EPrints::Search->new(
		session => $session,
		dataset => $session->dataset( 'ref_support_benchmark' ),
		allow_blank => 1,
	);

	my $list = $search->perform_search();

	$list->map( sub {
		my( $session, $ds, $object, $info ) = @_;

		return unless( defined $object );

		my $objectid = $object->get_id();

		if( "$objectid" eq $info->{selected} )
		{
			$object->set_value( 'default', 'TRUE' );
		}
		else
		{
			$object->set_value( 'default', 'FALSE' );
		}
		
		#sf2 - note: EPrints will only write to the DB if the value 'default' actually changed	
		$object->commit;

	}, { selected => "$id" } );

}

=item my $benchmark = EPrints::DataObj::REF_Support_Benchmark->default( $session );

Returns the Default Benchmark

=cut
sub default
{
	my( $class, $repo ) = @_;

	return $repo->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( default )], value => "TRUE", },
		])->item( 0 );
}

=item $list = $benchmark->selections

Returns all selections for this benchmark.

=cut
sub selections
{
	my( $self ) = @_;

	return $self->{session}->dataset( "ref_support_selection" )->search(
		filters => [
			{ meta_fields => [qw( ref_support_benchmarkid )], value => $self->id },
		],
		custom_order => "selectionid",
	);
}

=item $list = $benchmark->user_selections( $user )

Returns the user selections for this benchmark.

=cut
sub user_selections
{
	my( $self, $user ) = @_;

	return $self->{session}->dataset( "ref_support_selection" )->search(
		filters => [
			{ meta_fields => [qw( ref_support_benchmarkid )], value => $self->id },
			{ meta_fields => [qw( user_id )], value => $user->id },
		],
		custom_order => "selectionid",
	);
}

=item $list = $benchmark->eprint_selections( $eprint )

Returns the selections for eprint for this benchmark.

=cut
sub eprint_selections
{
	my( $self, $eprint ) = @_;

	return $self->{session}->dataset( "ref_support_selection" )->search(
		filters => [
			{ meta_fields => [qw( ref_support_benchmarkid )], value => $self->id },
			{ meta_fields => [qw( eprint_id )], value => $eprint->id },
		],
		custom_order => "selectionid",
	);
}

=item $list = $benchmark->uoa_selections( $subject )

Returns the selections for UoA $subject for this benchmark.

=cut
sub uoa_selections
{
	my( $self, $subject ) = @_;

	my $repo = $self->{session};
	my $dataset = $repo->dataset( "ref_support_selection" );
	my $db = $repo->get_database;

	# EPrints 3.2 doesn't support compound matches so we'll perform direct SQL
	# here for performance reasons
	my $key_field = $dataset->get_key_field;

	my $benchmark_field = $dataset->field( "ref_support_benchmarkid" );
	my $uoa_field = $dataset->field( "ref_support_uoa" );

	my $main_table = $dataset->get_sql_table_name;
	my $benchmark_table = $dataset->get_sql_sub_table_name( $benchmark_field );
	my $uoa_table = $dataset->get_sql_sub_table_name( $uoa_field );

	my $Q_key_field = $db->quote_identifier( $key_field->get_sql_name );

	my $Q_main_table = $db->quote_identifier( $main_table );
	my $Q_benchmark_table = $db->quote_identifier( $benchmark_table );
	my $Q_uoa_table = $db->quote_identifier( $uoa_table );

	my $Q_benchmark_field = $db->quote_identifier( $benchmark_field->get_sql_name );
	my $Q_uoa_field = $db->quote_identifier( $uoa_field->get_sql_name );

	my $sql = <<"SQL";
SELECT
	$Q_main_table.$Q_key_field
FROM
	$Q_main_table, $Q_benchmark_table, $Q_uoa_table
WHERE
	$Q_main_table.$Q_key_field=$Q_benchmark_table.$Q_key_field AND
	$Q_benchmark_table.$Q_key_field=$Q_uoa_table.$Q_key_field AND
	$Q_benchmark_table.pos=$Q_uoa_table.pos AND
	$Q_benchmark_field=? AND
	$Q_uoa_field=?
ORDER BY
	user_id ASC,$Q_main_table.$Q_key_field ASC
SQL
	my $sth = $db->prepare( $sql );
	$sth->execute( $self->id, $subject->id );

	my @ids;

	my $id;
	$sth->bind_col( 1, \$id );
	while($sth->fetch)
	{
		push @ids, $id;
	}

	return $dataset->list( \@ids );
}

1;
}
