$c->{plugins}{"Screen::REF_Support::Report::Complete_Submission"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Research_Groups"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Current_Staff"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Former_Staff"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Former_Staff_Contracts"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Research_Outputs"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Staff_Outputs"}{params}{disable} = 0;

$c->{ref_2021_reports} = [qw{ complete_submission research_groups ref1_current_staff ref1_former_staff ref1_former_staff_contracts ref2_research_outputs ref2_staff_outputs }];

# Current Staff Fields
$c->{'ref'}->{'ref1_current_staff'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier surname initials dateOfBirth orcid contractFTE researchConnection reasonForNoConnectionStatement isEarlyCareerResearcher isOnFixedTermContract contractStartDate contractEndDate isOnSecondment secondmentStartDate secondmentEndDate isOnUnpaidLeave unpaidLeaveStartDate unpaidLeaveEndDate researchGroup }];

$c->{'ref'}->{'ref1_current_staff'}->{'mappings'} = {
	hesaStaffIdentifier => "user.hesa",
        staffIdentifier => "user.staff_id",
        surname => \&ref1a_support_surname,
        initials => \&ref1a_support_initials,
        dateOfBirth => "user.dob",
	orcid => \&ref2021_orcid,
        contractFTE => "user.ref_fte",
	researchConnection => "user.research_connection",
	reasonForNoConnectionStatement => \&ref2021_reason_no_connections,
        isEarlyCareerResearcher => "ref_support_circ.is_ecr",
        isOnFixedTermContract => "ref_support_circ.is_fixed_term",
        contractStartDate => "ref_support_circ.fixed_term_start",
        contractEndDate => "ref_support_circ.fixed_term_end",
        isOnSecondment => "ref_support_circ.is_secondment",
        secondmentStartDate => "ref_support_circ.secondment_start",
        secondmentEndDate => "ref_support_circ.secondment_end",
        isOnUnpaidLeave => "ref_support_circ.is_unpaid_leave",
        unpaidLeaveStartDate => "ref_support_circ.unpaid_leave_start",
        unpaidLeaveEndDate => "ref_support_circ.unpaid_leave_end",
	researchGroup => \&ref2021_research_groups,
        # + ResearchGroup[1|2|3|4]
};      

sub ref2021_orcid
{
        my( $plugin, $objects ) = @_;

        my $user = $objects->{user} or return;

	my $ds = $user->dataset;
	
	if( $ds->has_field( 'orcid' ) )
	{
		my $orcid = $user->value( 'orcid' );

		# regexp to match various ways an orcid could be stored, e.g.
		# Full URL: http://orcid.org/0000-1234-1234-123X
		# Full URL: https://orcid.org/0000-1234-1234-123X
		# Namespaced: orcid.org/0000-1234-1234-123X
		# or		: orcid:0000-1234-1234-123X
		# or value	: 0000-1234-1234-123X
		# or even	: 000012341234123X
		# 
		# Borrowed from https://github.com/eprints/orcid_support/commit/4fa9c37e1de7ca7570703ddf4539c055e8a0008d (credit: John Salter)
		if( defined $orcid && $orcid =~ m/^(?:\s*(?:https?:\/\/)?orcid(?:\.org\/|:))?(\d{4}\-?\d{4}\-?\d{4}\-?\d{3}(?:\d|X))(?:\s*)$/ )
		{
			return $1;
		}
	}

	return undef;
};

sub ref2021_research_groups
{
	my( $plugin, $objects ) = @_;
	
	my $user = $objects->{user} or return;

	if( $user->is_set( "research_groups" ) )
	{
		return join( ";", @{$user->get_value( "research_groups" )} )
	}

	return undef;
}

sub ref2021_reason_no_connections
{
	my( $plugin, $objects ) = @_;
	
	my $user = $objects->{user} or return;

	if( $user->is_set( "reason_no_connections" ) )
	{
		return join( ";", @{$user->get_value( "reason_no_connections" )} )
	}

	return undef;
}

# Former Staff Fields
$c->{'ref'}->{'ref1_former_staff'}->{'fields'} = [qw{ staffIdentifier surname initials dateOfBirth orcid excludeFromSubmission contracts }];

$c->{'ref'}->{'ref1_former_staff'}->{'mappings'} = {
	hesaStaffIdentifier => "user.hesa",
        staffIdentifier => "user.staff_id",
        surname => \&ref1a_support_surname,
        initials => \&ref1a_support_initials,
        dateOfBirth => "user.dob",
	orcid => \&ref2021_orcid,
	excludeFromSubmission => "user.exclude_from_submission",
	contracts => \&ref2021_contracts,
};      

sub ref2021_contracts
{
	my( $plugin, $objects ) = @_;
	
	# we need to call the former staff contracts report for this...
	my $session = $plugin->{session};

	# prep the export plugin
	my $export_plugin = $plugin;
	$export_plugin->{ref_fields} = undef;
	$export_plugin->{ref_fields_order} = undef;
        $export_plugin->{report} = 'ref1_former_staff_contracts';
        
	# get the contracts and use the export plugin to export each one
	my $no_escape = 1;
	my $contracts = EPrints::DataObj::REF_Support_Circ->search_by_user( $session, $objects->{user} );
	my $results;
	$contracts->map( sub {
		my( undef, undef, $contract ) = @_;	

		# this is currently a hacky solution for an XML export only...
		$results = $results."<contract>".$export_plugin->output_dataobj( $contract )."</contract>"; 
	} );
        
	# return the results
	return ( $results, $no_escape );
}

# Former Staff Contracts Fields
$c->{'ref'}->{'ref1_former_staff_contracts'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier contractFTE researchConnection reasonForNoConnectionStatement startDate endDate isOnSecondment secondmentStartDate secondmentEndDate isOnUnpaidLeave unpaidLeaveStartDate unpaidLeaveEndDate researchGroup }];

$c->{'ref'}->{'ref1_former_staff_contracts'}->{'mappings'} = {
	staffIdentifier => "user.staff_id",
	hesaStaffIdentifier => "user.hesa",
        contractFTE => "user.ref_fte",
	researchConnection => "user.research_connection",
	reasonForNoConnectionStatement => \&ref2021_reason_no_connections,
	startDate => "ref_support_circ.fixed_term_start",
	endDate => "ref_support_circ.fixed_term_end",
        isOnSecondment => "ref_support_circ.is_secondment",
        secondmentStartDate => "ref_support_circ.secondment_start",
        secondmentEndDate => "ref_support_circ.secondment_end",
        isOnUnpaidLeave => "ref_support_circ.is_unpaid_leave",
        unpaidLeaveStartDate => "ref_support_circ.unpaid_leave_start",
        unpaidLeaveEndDate => "ref_support_circ.unpaid_leave_end",
	researchGroup => \&ref2021_research_groups,
};      

# Research Groups Fields
$c->{'ref'}->{'research_groups'}->{'fields'} = [qw{ code name }];

$c->{'ref'}->{'research_groups'}->{'mappings'} = {
        code => "ref_support_rg.code",
	name => "ref_support_rg.name",
};

# Research Outputs Fields
$c->{'ref'}->{'ref2_research_outputs'}->{'fields'} = [qw{ outputIdentifier webOfScienceIdentifier outputType title place publisher volumeTitle volume issue firstPage articleNumber isbn issn doi patentNumber month year url isPhysicalOutput supplementaryInformationDOI numberOfAdditionalAuthors isPendingPublication pendingPublicationReserve isForensicScienceOutput isCriminologyOutput isNonEnglishLanguage englishAbstract isInterdisciplinary proposeDoubleWeighting doubleWeightingStatement doubleWeightingReserve conflictedPanelMembers crossReferToUoa additionalInformation researchGroup openAccessStatus outputAllocation outputSubProfileCategory requiresAuthorContributionStatement isSensitive excludeFromSubmission }];

$c->{'ref'}->{'ref2_research_outputs'}->{'mappings'} = {
	"outputIdentifier" => "ref_support_selection.selectionid",
	"webOfScienceIdentifier" => "ref_support_selection.wos_id",
	"outputType" => "ref_support_selection.type",
	"title" => "eprint.title",
	"place" => "eprint.event_location",
	"publisher" => "eprint.publisher",
	"volumeTitle" => \&ref2_support_volumeTitle,
	"volume" => "eprint.volume",
	"issue" => "eprint.number",
	"firstPage" => \&ref2_support_firstPage,
	"articleNumber" => \&ref2_support_article_number,
	"isbn" => "eprint.isbn",
	"issn" => "eprint.issn",
	"doi" => "eprint.id_number",
	"patentNumber" => \&ref2_support_patentNumber,
	"month" => \&ref2021_month,
	"year" => \&ref2_support_year,
	"url" => \&ref2_support_url,
	"isPhysicalOutput" => "ref_support_selection.is_physical_output",
	"supplementaryInformationDOI" => "ref_support_selection.supplementary_information_doi",
	"numberOfAdditionalAuthors" => \&ref2_support_additionalAuthors,
	"isPendingPublication" => "ref_support_selection.pending",
	"pendingPublicationReserve" => "ref_support_selection.pending_publication",
	"isForensicScienceOutput" => "ref_support_selection.is_forensic",
	"isCriminologyOutput" => "ref_support_selection.is_criminology",
	"isNonEnglishLanguage" => "ref_support_selection.non_english",
	"englishAbstract" => "ref_support_selection.abstract",
	"isInterdisciplinary" => "ref_support_selection.interdis",
	"proposeDoubleWeighting" => \&ref2_support_doubleWeighting,
	"doubleWeightingStatement" => "ref_support_selection.weight_text",
	"doubleWeightingReserve" => "ref_support_selection.double_reserve",
	"conflictedPanelMembers" => "ref_support_selection.conflicted_members",
	"crossReferToUoa" => \&ref2_support_cross_ref,
	"additionalInformation" => "ref_support_selection.details",
	"researchGroup" => "ref_support_selection.research_group",
	"openAccessStatus" => "ref_support_selection.open_access_status",
	"outputAllocation" => "ref_support_selection.output_allocation",
	"outputSubProfileCategory" => "ref_support_selection.output_sub_profile_cat",
	"requiresAuthorContributionStatement" => "ref_support_selection.author_statement",
	"isSensitive" => "ref_support_selection.sensitive",
	"excludeFromSubmission" => "ref_support_selection.exclude_from_submission",
};

sub ref2021_month
{
        my( $plugin, $objects ) = @_;

        my $eprint = $objects->{eprint};

	my( $year, $month, $day ) = split(/-/, $eprint->value( "date" ) );
	return $month if defined $month;

	return undef;
}

# Link between staff and outputs fields
$c->{'ref'}->{'ref2_staff_outputs'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier outputIdentifier authorContributionStatement }];

$c->{'ref'}->{'ref2_staff_outputs'}->{'mappings'} = {
        "hesaStaffIdentifier" => "user.hesa",
        "staffIdentifier" => "user.staff_id",
        "outputIdentifier" => "ref_support_selection.selectionid",
        "authorContributionStatement" => "ref_support_selection.author_statement_text",
};
