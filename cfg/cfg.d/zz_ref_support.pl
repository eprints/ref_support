#
# EPrints Services - REF Package
#
# Version: 2.0
#

# Bazaar Configuration
$c->{plugins}{"Export::REF_Support"}{params}{disable} = 0;
$c->{plugins}{"Export::REF_Support::REF_XML"}{params}{disable} = 0;
#$c->{plugins}{"Export::REF_Support::REF_JSON"}{params}{disable} = 0;
$c->{plugins}{"Export::REF_Support::REF_CSV"}{params}{disable} = 0;
$c->{plugins}{"Export::REF_Support::REF_Excel"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Benchmark::Select"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Benchmark::Copy"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Benchmark::New"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Benchmark::LinkListing"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Benchmark::Destroy"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Benchmark::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::User::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::User::EditUoA"}{params}{disable} = 0;
#$c->{plugins}{"Screen::REF_Support::User::EditCirc"}{params}{disable} = 0;
#$c->{plugins}{"Screen::REF_Support::User::EditCircLink"}{params}{disable} = 0;
#$c->{plugins}{"Screen::REF_Support::User::EditCircLinkBack"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::User::ManageContracts"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Listing"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Overview"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Listing"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::REF1a"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::REF1b"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::REF1c"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::REF2"}{params}{disable} = 0;

#hide old versions of plugin from user profile screen
$c->{plugins}->{"Screen::REF::User::Edit"}->{appears}->{dataobj_view_actions} = undef;
$c->{plugins}->{"Screen::REF::User::EditUoA"}->{appears}->{dataobj_view_actions} = undef;
$c->{plugins}->{"Screen::REF::User::EditCircLink"}->{appears}->{dataobj_view_actions} = undef;

# Main switch (used for 3.2 backport)
$c->{ref_enabled} = 1;

# The name of your institution (used by reports) - otherwise it will default to the Repository name
# $c->{'ref'}->{'institution'} = 'University of XYZ';

# The action that appears in the (exported) Reports (will default to 'Update');
# $c->{'ref'}->{'action'} = 'Update';

# Controls which reports a 'normal' (non-Champion) can view (see REF::Overview)
# available reports/data: ref/view/ref1a, ref/view/ref1b, ref/view/ref1c
push @{$c->{user_roles}->{user}}, qw{
	ref/view/ref2
};

push @{$c->{user_roles}->{editor}}, qw{
	ref/view/ref2
};

push @{$c->{user_roles}->{admin}}, qw{
	ref/view/ref2
};

# ref/edit/ref1abc controls the behaviour of REF::User::Edit and REF::User::EditCirc (which should be together really)
# ref/edit/ref2 is not implemented, it's actually controlled by ref/select (see REF::Listing)
#push @{$c->{user_roles}->{user}}, qw{
#	ref/edit/ref1abc
#};

# You may have a custom method that checks who can see the Listing and Overview screens
# The commented-out example below forbids anyone who doesn't have the ref/select role
# from seeeing their own selections (e.g. if they've been made on their behalf)
#$c->{ref_can_user_view_listing} = sub {
#
#	my( $session ) = @_;
#
#	# let the uoa champion see the screen:
#	return 1 if( $self->{session}->current_user->exists_and_set( 'ref_uoa_role' ) );
#
#	return 1 if( $self->{session}->current_user->exists_and_set( 'ref_uoa' ) && $self->{session}->current_user->has_role( 'ref/select' ) );
#
#	return 0;
#};


# used for the dataobjref metafields (see dataset "ref_support_selection")
$c->{datasets}->{eprint}->{search}->{simple}->{meta_fields} = [ "title", "abstract" ];
$c->{datasets}->{user}->{search}->{simple}->{meta_fields} = [ "name", "username" ];


# Un-comment the line below to search publications by author id ( == user.email or == role.email ) rather than by author name
# $c->{'ref_support'}->{search_authored}->{by_id} = 1;

# by default the above option will map user.email to eprint.creators_id. But perhaps you'd like to use some other fields, in which case un-comment
# the following:
# $c->{'ref_support'}->{search_authored}->{by_id_fields} = {
#	user_field => userid,
#	eprint_field => creators_browse_id,
# };


# Sets the datasets to search on the REF::Listing screen. By default, it will only search "archive".
# If you want to search archive + buffer, change this to 'archive buffer'
# If you want to search archive + buffer + inbox, change this to 'archive buffer inbox'
$c->{'ref_support'}->{listing_search_datasets} = 'archive';

# Default search to run on the REF::Listing page (un-comment the one you want):
$c->{'ref_support'}->{default_search} = 'search_authored';	# items that the user has co-authored
#$c->{'ref_support'}->{default_search} = 'search_deposited';	# items that the user has deposited
#$c->{'ref_support'}->{default_search} = '';			# will show an empty search form

# Flags for assessor rating and assessor rating visibility
# Un-comment the line below to show the assessor_rating field
# $c->{'ref_support'}->{assessor_rating} = 1;

# If a user's UoA has changed, this will also update all the REF Selection objects referencing the pair (user,uoa)
$c->add_dataset_trigger( "user", EPrints::Const::EP_TRIGGER_AFTER_COMMIT, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $user = $params{dataobj};
	my $changed = $params{changed};
	my $uoa_id = $changed->{ref_support_uoa};

	return if !defined $uoa_id;
	return if !$user->is_set( "ref_support_uoa" );

	my $benchmark = EPrints::DataObj::REF_Support_Benchmark->default( $repo );
	return if !defined $benchmark;

	$benchmark->user_selections( $user )->map(sub {
		(undef, undef, my $selection) = @_;

		$selection->unselect_for( $benchmark );
		$selection->select_for( $benchmark, $user->value( "ref_support_uoa" ) );
		$selection->{non_volatile_change} = 0;
		$selection->commit;
	});
});

# called when a ref_support_selection object is committed
$c->{set_ref_support_selection_automatic_fields} = sub {
	my( $selection ) = @_;

	my $session = $selection->get_session;

	# Re-sync the EPrint title while we're here
	my $eprint = $session->dataset( 'eprint' )->dataobj( $selection->value( 'eprint_id' ) );

	if( defined $eprint )
	{
		$selection->set_value( 'eprint_title', $eprint->value( 'title' ) );

		unless( $selection->is_set( 'type' ) )
		{
			# see zz_ref_report.pl for $c->{ref}->{map_eprint_type}
			$selection->set_value( 'type', $session->call( [ 'ref', 'map_eprint_type' ], $eprint ) );
		}
	}
};

# If the title of an EPrint changes, we need to update the REF Selection objects
$c->add_dataset_trigger( "eprint", EPrints::Const::EP_TRIGGER_AFTER_COMMIT, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $eprint = $params{dataobj};
	my $changed = $params{changed};
	my $new_title = $changed->{title} or return;

	$repo->dataset( 'ref_support_selection' )->search(
		filters => [ { 
			meta_fields => [ 'eprint_id' ], 
			value => $eprint->get_id
	} ] )->map( sub {
		my( undef, undef, $selection ) = @_;

		$selection->set_value( 'eprint_title', $new_title );
		$selection->commit;
	} );
});


# 
# REF Selection object
#

{
no warnings;

package EPrints::DataObj::REF_Support_Selection;

@EPrints::DataObj::REF_Support_Selection::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "ref_support_selection" }

sub get_url { shift->uri }

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;

	$data = $class->SUPER::get_defaults( @_[1..$#_] );

	$data->{weight} = "single";
	$data->{lastmod} = $data->{datestamp} = EPrints::Time::get_iso_timestamp();

	return $data;
}

sub get_control_url { $_[0]->{session}->config( "userhome" )."?screen=REF_Support::Edit&selectionid=".$_[0]->get_id }

=item $selection = EPrints::DataObj::REF_Support_Selection::create_from_parts( $session, %parts )

Creates a new REF Selection object based on the %parts (eprint,user, user_actual objects)

=cut
sub create_from_parts
{
	my( $class, $session, %parts ) = @_;

	my( $eprint, $user, $user_actual ) = @parts{qw( eprint user user_actual )};

	return $class->create_from_data( $session, {
		eprint => {
			id => $eprint->id,
			title => $session->xhtml->to_text_dump( $eprint->render_description ),
		},
		user => {
			id => $user->id,
			title => $session->xhtml->to_text_dump( $user->render_description ),
		},
		user_actual => {
			id => $user_actual->id,
			title => $session->xhtml->to_text_dump( $user_actual->render_description ),
		},
	});
}

=item $selection = EPrints::DataObj::REF_Support_Selection::new_from_parts( $session, %parts )

Instanciates an existing REF Selection object based on the provided %parts (eprint,user, user_actual objects)

=cut
sub new_from_parts
{
	my( $class, $session, %parts ) = @_;

	my( $eprint, $user, $user_actual ) = @parts{qw( eprint user user_actual )};

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( eprint_id )], value => $eprint->id, match => "EX", },
			{ meta_fields => [qw( user_id )], value => $user->id, match => "EX", },
		],
	)->item( 0 );
}

=item $list = EPrints::DataObj::REF_Support_Selection::search_by_user( $session, $user )

Returns the REF Selection objects belonging to $user

=cut
sub search_by_user
{
	my( $class, $session, $user ) = @_;

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( user_id )], value => $user->id, match => "EX", },
		],
	);
}

=item $list = EPrints::DataObj::REF_Support_Selection::search_by_eprint( $session, $eprint )

Returns the REF Selection objects attached to the $eprint object

=cut
sub search_by_eprint
{
	my( $class, $session, $eprint ) = @_;

	return $class->search_by_eprintid( $session, $eprint->get_id );

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( eprint_id )], value => $eprint->id, match => "EX", },
		],
	);
}

=item $list = EPrints::DataObj::REF_Support_Selection::search_by_eprintid( $session, $eprint )

Returns the REF Selection objects attached to $eprintid

=cut
sub search_by_eprintid
{
	my( $class, $session, $eprintid ) = @_;

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( eprint_id )], value => $eprintid, match => "EX", },
		],
	);
}


=item $arrayref = EPrints::DataObj::REF_Support_Selection::who_selected( $session, $eprint )

Returns a list of user IDs who have selected the $eprintid for REF

=cut
sub who_selected
{
        my( $class, $session, $eprintid ) = @_;

        my $list = $class->search_by_eprintid( $session, $eprintid );

        my @userids;

        # extract all userids from REF_Support_Selection objects:
        $list->map( sub { push @{$_[3]->{userids}}, $_[2]->get_value( "user_id" ) }, { userids => \@userids } );

        return \@userids;
}



=item $selection->select_for( $benchmark, $uoa_id )

Add this selection to the given benchmark for the given UoA.

=cut
sub select_for
{
	my( $self, $benchmark, $uoa_id ) = @_;

	foreach my $ref (@{$self->value( "ref_support" )})
	{
		return if $ref->{benchmarkid} == $benchmark->id;
	}
	
	$self->set_value( "ref_support", [
		@{$self->value( "ref_support" )},
		{ uoa => $uoa_id, benchmarkid => $benchmark->id },
	]);
}

=item $selection->unselect_for( $benchmark )

Remove this selection from the given benchmark.

=cut
sub unselect_for
{
	my( $self, $benchmark ) = @_;

	my @ref;
	foreach my $ref (@{$self->value( "ref_support" )})
	{
		push @ref, $ref if $ref->{benchmarkid} != $benchmark->id;
	}

	$self->set_value( "ref_support", \@ref );
}

sub current_uoa
{
	my( $self ) = @_;

	my $bm = EPrints::DataObj::REF_Support_Benchmark->default( $self->{session} );

	return undef if !defined $bm;

	return $self->uoa( $bm );
}

=item $uoa = $selection->uoa( $benchmark )

Returns the UoA this selection is being submitted to, for the given benchmark.

=cut
sub uoa
{
	my( $self, $benchmark ) = @_;

	foreach my $ref (@{$self->value( "ref_support" )})
	{
		return $ref->{uoa} if $ref->{benchmarkid} == $benchmark->id;
	}

	return undef; # oops
}

sub commit
{
	my( $self, $force ) = @_;

	unless( $self->is_set( 'datestamp' ) )
	{
		$self->set_value( 'datestamp', EPrints::Time::get_iso_timestamp() );
	}

	# this will call set_ref_support_selection_automatic_fields
	$self->update_triggers();

        if( scalar( keys %{$self->{changed}} ) == 0 )
        {
                # don't do anything if there isn't anything to do
                return( 1 ) unless $force;
        }

	if( !$self->{non_volatile_change} )
	{
		$self->set_value( 'lastmod', EPrints::Time::get_iso_timestamp() );
	}

	return $self->SUPER::commit( $force );
}

sub get_warnings
{       
        my( $self , $for_archive ) = @_;
	
	# validation of the ref_support_selection object

	return [];
}

} # end of package


# REF Selection Dataset definition

$c->{datasets}->{ref_support_selection} = {
	class => "EPrints::DataObj::REF_Support_Selection",
	sqlname => "ref_support_selection",
	name => "ref_support_selection",
	columns => [qw( selectionid userid eprintid userid_actual )],
	index => 1,
	import => 1,
	search => {                
		simple => {
                        search_fields => [{
                                id => "q",
                                meta_fields => [qw(
					selectionid
					userid
                                        eprintid
					userid_actual
                                )],
                        }],
                        order_methods => {
                                "byuserid"         =>  "-eprintid/userid",
                                "byeprintid"        =>  "userid/eprintid",
                        },
                        default_order => "byuserid",
                        show_zero_results => 1,
                        citation => "result",
                },
        },
};


# REF Selection Fields definition

# internal fields
$c->add_dataset_field( 'ref_support_selection', { name => "selectionid", type=>"counter", required=>1, can_clone=>0, sql_counter=>"selectionid" }, reuse => 1 );
# user who made the selection
$c->add_dataset_field( 'ref_support_selection',  { name => "user", type=>"dataobjref", required=>1, datasetid=>"user", fields => [ { sub_name => 'title', type => 'text' } ]}, reuse => 1 );
# selected eprint
$c->add_dataset_field( 'ref_support_selection', { name => "eprint", type=>"dataobjref", required=>1, datasetid=>"eprint",fields=>[ { sub_name => 'title', type => 'text' } ]}, reuse => 1 );
# user for whom the selection has been made (can be the same as 'user' above)
$c->add_dataset_field( 'ref_support_selection', { name => "user_actual", type=>"dataobjref", required=>1, datasetid=>"user",fields=>[ { sub_name => 'title', type => 'text' } ]}, reuse => 1 );
# when this selection was made
$c->add_dataset_field( 'ref_support_selection', { name => "datestamp", type=>"timestamp", required=>0, import=>0, render_res=>"minute", render_style=>"short", can_clone=>0 }, reuse => 1 );
# when this selection was last modified
$c->add_dataset_field( 'ref_support_selection', { name => "lastmod", type=>"timestamp", required=>0, import=>0, render_res=>"minute", render_style=>"short", can_clone=>0 }, reuse => 1 );
# a compound referencing the benchmark this selection is made against, as well as its UoA
$c->add_dataset_field( 'ref_support_selection', {
			name => "ref_support",
			type => "compound",
			multiple => 1,
			fields => [
				{ sub_name => "benchmarkid", type => "itemref", datasetid => "ref_support_benchmark", },
				{ sub_name => "uoa", type => "subject", top => $c->{ref_support}->{uoas}, },
			],
		}, reuse => 1 );
# outputType
$c->add_dataset_field( 'ref_support_selection',	{ name => "type", type=>"set", options=>[qw( A B C D E F G H I J K L M N O P Q R S T U V )], }, reuse => 1 );
# outputNumber: not actually used - the number's set automatically
$c->add_dataset_field( 'ref_support_selection', { name => "position", type => "int", }, reuse => 1 );
# isInterdisciplinary
$c->add_dataset_field( 'ref_support_selection', { name => "interdis", type => "boolean" },reuse => 1 );
# crossReferToUoa
$c->add_dataset_field( 'ref_support_selection', { name => "xref", type => "subject", top => $c->{ref_support}->{uoas}, }, reuse => 1 );
# isOutputCrossReferred
$c->add_dataset_field( 'ref_support_selection', { name => "is_xref", type => 'boolean' }, reuse => 1 );
# additionalInformation
$c->add_dataset_field( 'ref_support_selection', { name => "details", type => "longtext" }, reuse => 1 );
# englishAbstract - should be copied from the eprint?
$c->add_dataset_field( 'ref_support_selection', { name => "abstract", type => "longtext" }, reuse => 1 );
# not sure this is the right format for proposeDoubleWeighting (this seems a cross between proposeDoubleWeighting and reserveOutput)
$c->add_dataset_field( 'ref_support_selection', { name => "weight", type => "set", options => [qw( single double )], required => 1 }, reuse => 1 );
# doubleWeightingStatement
$c->add_dataset_field( 'ref_support_selection', { name => "weight_text", type => "longtext" }, reuse => 1 );
# reserveOutput
$c->add_dataset_field( 'ref_support_selection', { name => "reserve", type => "set", options => [1,2,3,4] }, reuse => 1 );
# self rating - note: not submitted to REF
$c->add_dataset_field( 'ref_support_selection', { name => "self_rating", type => "set", options => [0, 1, 2, 3, 4] }, reuse => 1 );
# assessor rating - note: not submitted to REF
$c->add_dataset_field( 'ref_support_selection', { name => "assessor_rating", type => "set", options => [0, 1, 2, 3, 4] }, reuse => 1 );
# isPendingPublication
$c->add_dataset_field( 'ref_support_selection', { name => 'pending', type => 'boolean' }, reuse => 1 );
# isDuplicateOutput - this can be automatically set?
$c->add_dataset_field( 'ref_support_selection', { name => 'duplicate', type => 'boolean' }, reuse => 1 );
# isNonEnglishOutput
$c->add_dataset_field( 'ref_support_selection', { name => 'non_english', type => 'boolean' }, reuse => 1 );
# hasConflictsOfInterests
$c->add_dataset_field( 'ref_support_selection', { name => 'has_conflicts', type => 'boolean' }, reuse => 1 );
# conflictedPanelMembers
$c->add_dataset_field( 'ref_support_selection', { name => 'conflicted_members', type => 'longtext' }, reuse => 1 );
# isSensitive
$c->add_dataset_field( 'ref_support_selection', { name => 'sensitive', type => 'boolean' }, reuse => 1 );
# researchGroup (just a free form text, no validation done on it)
$c->add_dataset_field( 'ref_support_selection', { name => 'research_group', type => 'text', maxlength => 1 }, reuse => 1 );
# Article number
$c->add_dataset_field( 'ref_support_selection', { name => 'article_id', type => 'text' }, reuse => 1 );

# webOfScienceIdentifier
$c->add_dataset_field( 'ref_support_selection', { name => 'wos_id', type => 'text' }, reuse => 1 );

# isPhysicalOutput
$c->add_dataset_field( 'ref_support_selection', { name => 'is_physical_output', type => 'boolean' }, reuse => 1 );

# supplementaryInformationDOI
$c->add_dataset_field( 'ref_support_selection', { name => 'supplementary_information_doi', type => 'text' }, reuse => 1 );

# pendingPublicationReserve
$c->add_dataset_field( 'ref_support_selection', { name => 'pending_publication', type => 'itemref', datasetid => 'ref_support_selection' } );

# isForensicScienceOutput
$c->add_dataset_field( 'ref_support_selection', { name => 'is_forensic', type => 'boolean' }, reuse => 1 );

# isCriminologyOutput
$c->add_dataset_field( 'ref_support_selection', { name => 'is_criminology', type => 'boolean' }, reuse => 1 );

# doubleWeightingReserve
$c->add_dataset_field( 'ref_support_selection', { name => 'double_reserve', type => 'itemref', datasetid => 'ref_support_selection' }, reuse => 1 );

# openAccessStatus
$c->add_dataset_field( 'ref_support_selection', { 
			name => 'open_access_status',
			type => 'set',
			options => [
				'Compliant',
				'NotCompliant',
				'DepositException',
				'AccessException',
				'TechnicalException',
				'OtherException',
				'OutOfScope',
				'ExceptionWithin3MonthsOfPublication',
			],
		}, reuse => 1 );

# outputAllocation1
$c->add_dataset_field( 'ref_support_selection', { name => 'output_allocation', type => 'text' }, reuse => 1 );

# outputAllocation2
$c->add_dataset_field( 'ref_support_selection', { name => 'output_allocation_2', type => 'text' }, reuse => 1 );

# outputSubProfileCategory
$c->add_dataset_field( 'ref_support_selection', { name => 'output_sub_profile_cat', type => 'text' }, reuse => 1 );

# requiresAuthorContributionStatement
$c->add_dataset_field( 'ref_support_selection', { name => 'author_statement', type => 'boolean' }, reuse => 1 );

# authorContributionStatement
$c->add_dataset_field( 'ref_support_selection', { name => 'author_statement_text', type => 'text' }, reuse => 1 );

# excludeFromSubmission
$c->add_dataset_field( 'ref_support_selection', { name => 'exclude_from_submission', type => 'boolean' }, reuse=> 1 );

# outputPdfRequired
$c->add_dataset_field( 'ref_support_selection', { name => 'pdf_required', type => 'boolean' }, reuse=> 1 );	

# doesIncludeSignificantMaterialBefore2014
$c->add_dataset_field( 'ref_support_selection', { name => "does_include_sig", type => "boolean" }, reuse => 1 );

# doesIncludeResearchProcess
$c->add_dataset_field( 'ref_support_selection', { name => "does_include_res", type => "boolean" }, reuse => 1 );

# doesIncludeFactualInformationAboutSignificance
$c->add_dataset_field( 'ref_support_selection', { name => "does_include_fact", type => "boolean" }, reuse => 1 );

# isAdditionalAttributedStaffMember
$c->add_dataset_field( 'ref_support_selection', { name => "is_additional_staff", type => "boolean" }, reuse => 1 );


# REF Search Configuration (as used by REF::Listing)

$c->{search}->{"ref_support"} =
{
        search_fields => [
                { meta_fields => [ $EPrints::Utils::FULLTEXT ] },
                { meta_fields => [ "title" ] },
                { meta_fields => [ "creators_name" ] },
                { meta_fields => [ "abstract" ] },
                { meta_fields => [ "date" ] },
                { meta_fields => [ "keywords" ] },
                { meta_fields => [ "divisions" ] },
                { meta_fields => [ "subjects" ] },
                { meta_fields => [ "type" ] },
                { meta_fields => [ "editors_name" ] },
                { meta_fields => [ "ispublished" ] },
                { meta_fields => [ "refereed" ] },
                { meta_fields => [ "publication" ] },
                { meta_fields => [ "documents.format" ] },
                { meta_fields => [ "datestamp" ] },
        ],
        citation => "result",
        page_size => 20,
        order_methods => {
                "byyear"         => "-date/creators_name/title",
                "byyearoldest"   => "date/creators_name/title",
                "byname"         => "creators_name/-date/title",
                "bytitle"        => "title/creators_name/-date"
        },
        default_order => "byyear",
        show_zero_results => 1,
};


# returns an EPrints::List of User objects representing the user roles the given $user can assume
# note that you may build static list of users here
$c->{ref_support_roles_for_user} = sub
{
	my ( $session, $user ) = @_;
		
	my $list = EPrints::List->new(
		session => $session,
		dataset => $session->dataset( "user" ),
		ids => [],
	);

	if( $user->is_set( "ref_support_uoa_role" ) )
	{
		my $roles = $user->value( 'ref_support_uoa_role' );

		$list = $list->union( $session->dataset( "user" )->search(
	        	filters => [
				{ meta_fields => [qw( ref_support_uoa )], value => join( " ", @{$roles} ), match => "IN" },
			],
		));

		# sf2 - patch to make the Search works over Subject fields inside Compounds fields (fixed in 3.2.8)
		#foreach( @$roles )
		#{
		#	$list = $list->union( $session->dataset( "user" )->search(
	        #                filters => [
        	#                        { meta_fields => [qw( ref_support_uoa )], value => "$_", match => "EQ", merge => "ANY" },
                #	        ],
	        #        ));
		#}

	}
		
	return $list;
};


# User fields for REF

# date of birth
$c->add_dataset_field( 'user', { name => 'dob', type => 'date' }, reuse => 1 );
# HESA Identifier
$c->add_dataset_field( 'user', { name => 'hesa', type => 'id' }, reuse => 1 );
# (internal) Staff Identifier
$c->add_dataset_field( 'user', { name => 'staff_id', type => 'id' }, reuse => 1 );
# REF Staff Category
$c->add_dataset_field( 'user', { name => 'ref_category', type => 'set', options => [ 'A', 'C' ] }, reuse => 1 );
# REF Start dates
$c->add_dataset_field( 'user', { name => 'ref_start_date', type => 'date' }, reuse => 1 );
# REF End dates (not used) - removed in v1.2
# $c->add_dataset_field( 'user', { name => 'ref_end_date', type => 'date' }, reuse => 1 );
# FTE
$c->add_dataset_field( 'user', { name => 'ref_fte', type => 'float' }, reuse => 1 );
# Unit of Assessment
$c->add_dataset_field( 'user', { name => 'ref_support_uoa', type => 'subject', top => $c->{ref_support}->{uoas} }, reuse => 1 );
# UoA Champion
$c->add_dataset_field( 'user', { name => 'ref_support_uoa_role', type => 'subject', top => $c->{ref_support}->{uoas}, multiple => 1 }, reuse => 1 );
# isSensitive
$c->add_dataset_field( 'user', { name => 'ref_is_sensitive', type => 'boolean' }, reuse => 1 );

# Fields moved to the ref_circ dataset (see zz_ref_circ.pl) in v1.2:
#$c->add_dataset_field( 'user', { name => 'ref_is_ecr', type => 'boolean' }, reuse => 1 );
#$c->add_dataset_field( 'user', { name => 'ref_is_circ', type => 'set', options => [ 'fixed_term', 'secondment', 'unpaid_leave' ] }, reuse => 1 );
#$c->add_dataset_field( 'user', { name => 'ref_circ_start_date', type => 'date' }, reuse => 1 );
#$c->add_dataset_field( 'user', { name => 'ref_circ_end_date', type => 'date' }, reuse => 1 );

# Fields added for REF2021 Submissions
# researchConnection
$c->add_dataset_field( 'user', { name => 'research_connection', type => 'text' }, reuse => 1 );

# reasonForNoConnectionStatement
$c->add_dataset_field( 'user', { 
	name => 'reason_no_connections',
	type => 'set',
	multiple => 1,
	options => [ 'CaringResponsibilities', 'PersonalCircumstances', 'ReducedHours', 'NormalDisciplinePractice' ],
}, reuse => 1 );

# researchGroup
$c->add_dataset_field( 'user', {
	name => 'research_groups',
	type => 'text',
	maxlength => 1,
	multiple => 1,
}, reuse => 1 );

# excludeFromSubmission
$c->add_dataset_field( 'user', {
	name => 'exclude_from_submission',
	type => 'boolean',
}, reuse=> 1 );

# REF End date
$c->add_dataset_field( 'user', { name => 'ref_end_date', type => 'date' }, reuse => 1 );

# The circ dataset is now used to model former staff contracts,
# as such some of the old circ fields are now added to the user dataset
# for the current staff field
$c->add_dataset_field( 'user', { name => 'is_ecr', type => 'boolean' }, reuse => 1 );

# isOnFixedTermContract
$c->add_dataset_field( 'user', { name => 'is_fixed_term', type => 'boolean' }, reuse => 1 );
# contractStartDate
$c->add_dataset_field( 'user', { name => 'fixed_term_start', type => 'date' }, reuse => 1 );
# contractEndDate
$c->add_dataset_field( 'user', { name => 'fixed_term_end', type => 'date' }, reuse => 1 );

# isOnSecondment
$c->add_dataset_field( 'user', { name => 'is_secondment', type => 'boolean' }, reuse => 1 );
# secondmentStartDate
$c->add_dataset_field( 'user', { name => 'secondment_start', type => 'date' }, reuse => 1 );
# secondmentEndDate
$c->add_dataset_field( 'user', { name => 'secondment_end', type => 'date' }, reuse => 1 );

# isOnUnpaidLeave
$c->add_dataset_field( 'user', { name => 'is_unpaid_leave', type => 'boolean' }, reuse => 1 );
# unpaidLeaveStartDate
$c->add_dataset_field( 'user', { name => 'unpaid_leave_start', type => 'date' }, reuse => 1 );
# unpaidLeaveEndDate
$c->add_dataset_field( 'user', { name => 'unpaid_leave_end', type => 'date' }, reuse => 1 );

1;
