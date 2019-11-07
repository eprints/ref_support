$c->{plugins}{"Screen::REF_Support::Report::Complete_Submission"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Research_Groups"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Current_Staff"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Former_Staff"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Former_Staff_Contracts"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Research_Outputs"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Staff_Outputs"}{params}{disable} = 0;

$c->{ref_2021_reports} = [qw{ complete_submission research_groups ref1_current_staff ref1_former_staff ref1_former_staff_contracts ref2_research_outputs ref2_staff_outputs }];

sub ref_support_check_characters
{
        my( $session, $report, $plugin, $objects, $problems ) = @_;

	my $ds;
	my $fields_length = $session->config( 'ref_support', $report.'_fields_length' ) || {};

	my $field_mappings = $session->config( 'ref', $report, 'mappings' );

        foreach my $key ( sort keys %{$fields_length} )
        {
                #get the value...              
		my $value;
		my $ep_fieldname;

		my $ep_field = $field_mappings->{$key};
		if( ref( $ep_field ) eq 'CODE' )
		{
			eval
			{
                        	$value = &$ep_field( $plugin, $objects );
			};
		}
		elsif( $ep_field =~ /^([a-z_]+)\.([a-z_]+)$/ )  # using an object field to extract data from
                {
			# get the dataset
			my $ds_id = $1;
			$ds = $session->dataset( $ds_id ); 

			# get the fieldname...
			$ep_fieldname = $2;
			
			# get the value if a valid thing to ask for
			if( defined $ds && $ds->has_field( $ep_fieldname ) )
			{
				$value = $objects->{$ds_id}->value( $ep_fieldname );
			}
		}
	
		if( EPrints::Utils::is_set( $value ) )
		{
			my $maxlen = $fields_length->{$key};
                        my $curlen = length( $value );

			if( $curlen > $maxlen )
                        {
				my $desc = ( $ds->has_field( $key ) ) ? $session->html_phrase( "eprint_fieldname_$key" ) : $session->make_text( $key );
				push @$problems, { field => $ep_fieldname, desc => $session->html_phrase( 'ref_support:validate:char_limit', fieldname => $desc, maxlen => $session->make_text( $maxlen ) ) }; 
                        }
		}		
        }
}

sub ref_support_check_research_groups
{
        my( $session, $dataobj, $problems ) = @_;

	my $rgs = $dataobj->value( 'research_groups' );
	my $rg_ds = $session->dataset( 'ref_support_rg' );
	my $desc = $session->html_phrase( "user_fieldname_research_groups" );
	if( scalar @$rgs > 4 )
	{
		push @$problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:number_user_research_group', fieldname => $desc ) };
	}
	else # we have a valid number, so start checking each one is ok
	{
		foreach my $rg ( @$rgs )
		{
			# check each rg is only a single alpha-numeric character
			if( $rg !~ m/^[a-zA-Z0-9]$/ )
			{
				push @$problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:user_research_group_code', fieldname => $desc ) };
			}	

			# check an RG record exists for the UoA
			my $research_groups = EPrints::DataObj::REF_Support_Research_Group::search_by_uoa_and_code( $session, $dataobj->get_value( "ref_support_uoa" ), $rg );
			if( $research_groups->count == 0 )
			{
				push @$problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:no_user_research_group', fieldname => $desc ) };
			}
		}
	}
}

# Current Staff Fields
$c->{'ref'}->{'ref1_current_staff'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier surname initials dateOfBirth orcid contractFTE researchConnection isEarlyCareerResearcher isOnFixedTermContract contractStartDate contractEndDate isOnSecondment secondmentStartDate secondmentEndDate isOnUnpaidLeave unpaidLeaveStartDate unpaidLeaveEndDate researchGroups }];

$c->{'ref'}->{'ref1_current_staff'}->{'mappings'} = {
	hesaStaffIdentifier => "user.hesa",
        staffIdentifier => "user.staff_id",
        surname => \&ref1a_support_surname,
        initials => \&ref1a_support_initials,
        dateOfBirth => "user.dob",
	orcid => \&ref2021_orcid,
        contractFTE => "user.ref_fte",
	researchConnection => "user.research_connection",
        isEarlyCareerResearcher => "user.is_ecr",
        isOnFixedTermContract => "user.is_fixed_term",
        contractStartDate => "user.fixed_term_start",
        contractEndDate => "user.fixed_term_end",
        isOnSecondment => "user.is_secondment",
        secondmentStartDate => "user.secondment_start",
        secondmentEndDate => "user.secondment_end",
        isOnUnpaidLeave => "user.is_unpaid_leave",
        unpaidLeaveStartDate => "user.unpaid_leave_start",
        unpaidLeaveEndDate => "user.unpaid_leave_end",
	researchGroups => \&ref2021_research_groups,
        # + ResearchGroup[1|2|3|4]
};      

# character limits
$c->{'ref_support'}->{'ref1_current_staff_fields_length'} = {
        staffIdentifier => 24,
        surname => 64,
        initials => 12,
	researchConnection => 7500,
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
	
	# get the object we want to get research groups from - this will change depending on the type of report
	my $dataobj;
	my $report = $plugin->{report};
	if( $report eq "ref1_former_staff_contracts" )
	{
		$dataobj = $objects->{ref_support_circ};
	}	
	else
	{
		$dataobj = $objects->{user};
	}
	return if !defined $dataobj;

	if( $dataobj->is_set( "research_groups" ) )
	{
		if( $plugin->{is_hierarchical} )
		{
			my $results;
			my $no_escape = 1;
			foreach my $rg ( @{$dataobj->get_value( "research_groups" )} )
			{
				$results = $results . "<group>$rg</group>"; # a hack for an XML export plugin, but this is our only hierarchical plugin at present
			}
			return ( $results, $no_escape );
		}
		else
		{
			return join( ";", @{$dataobj->get_value( "research_groups" )} )
		}
	}

	return undef;
}

# Current Staff Validation
$c->{plugins}->{"Screen::REF_Support::Report::Current_Staff"}->{params}->{validate_user} = sub {
        my( $plugin, $objects ) = @_;

        my $session = $plugin->{session};
        my @problems;

	my $user = $objects->{user};

        # character length checks...
        &ref_support_check_characters( $session, 'ref1_current_staff', $plugin, $objects, \@problems );

	# research group check
	&ref_support_check_research_groups( $session, $user, \@problems );

	# hesa check
        my $ds = $user->dataset;
        my $hesa = $user->value( 'hesa' );
        if( defined $hesa && length( $hesa ) != 13  )
        {
                my $desc = $session->html_phrase( "user_fieldname_hesa" );
                push @problems, { field => "hesa", desc => $session->html_phrase( 'ref_support:validate:invalid_hesa', fieldname => $desc ) };
        }

        return @problems;
};


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

# character limits
$c->{'ref_support'}->{'ref1_former_staff_fields_length'} = {
        staffIdentifier => 24,
	surname => 64,
	initials => 12,
};

sub ref2021_contracts
{
	my( $plugin, $objects ) = @_;
	
	# we can't handle contracts as a separate field in flat exports
	if( !$plugin->{is_hierarchical} )
	{
		return undef;
	}

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

$c->{plugins}->{"Screen::REF_Support::Report::Former_Staff"}->{params}->{validate_user} = sub {
        my( $plugin, $objects ) = @_;
	
	my $session = $plugin->{session};
	my @problems;

	# character length checks...
	&ref_support_check_characters( $session, 'ref1_former_staff', $plugin, $objects, \@problems );

	# orcid check
	my $user = $objects->{user};
	my $ds = $user->dataset;
	my $orcid = $user->value( 'orcid' );
        if( defined $orcid && $orcid !~ m/^(?:\s*(?:https?:\/\/)?orcid(?:\.org\/|:))?(\d{4}\-?\d{4}\-?\d{4}\-?\d{3}(?:\d|X))(?:\s*)$/ )
        {
       		my $desc = $session->html_phrase( "user_fieldname_orcid" );
		push @problems, { field => "orcid", desc => $session->html_phrase( 'ref_support:validate:invalid_orcid', fieldname => $desc ) };
 	}
	return @problems;
};

# Former Staff Contracts Fields
$c->{'ref'}->{'ref1_former_staff_contracts'}->{'fields'} = [qw{ staffIdentifier hesaStaffIdentifier contractFTE researchConnection reasonForNoConnectionStatement startDate endDate isOnSecondment secondmentStartDate secondmentEndDate isOnUnpaidLeave unpaidLeaveStartDate unpaidLeaveEndDate researchGroups }];

$c->{'ref'}->{'ref1_former_staff_contracts'}->{'mappings'} = {
	staffIdentifier => \&ref2021_contract_staff_identifier,
	hesaStaffIdentifier => "user.hesa",
        contractFTE => "ref_support_circ.ref_fte",
	researchConnection => "ref_support_circ.research_connection",
	startDate => "ref_support_circ.fixed_term_start",
	endDate => "ref_support_circ.fixed_term_end",
        isOnSecondment => "ref_support_circ.is_secondment",
        secondmentStartDate => "ref_support_circ.secondment_start",
        secondmentEndDate => "ref_support_circ.secondment_end",
        isOnUnpaidLeave => "ref_support_circ.is_unpaid_leave",
        unpaidLeaveStartDate => "ref_support_circ.unpaid_leave_start",
        unpaidLeaveEndDate => "ref_support_circ.unpaid_leave_end",
	researchGroups => \&ref2021_research_groups,
};      

# character limits
$c->{'ref_support'}->{'ref1_former_staff_contracts_fields_length'} = {
	researchConnection => 7500,
};


sub ref2021_contract_staff_identifier
{
	my( $plugin, $objects ) = @_;
	
	# we only need to include this in flat exports...
	if( !$plugin->{is_hierarchical} )
	{
		my $user = $objects->{user};
		return $user->get_value( "staff_id" );
	}
	return undef;
}

# Former Staff Contracts Validation
$c->{plugins}->{"Screen::REF_Support::Report::Former_Staff_Contracts"}->{params}->{validate_circ} = sub {
        my( $plugin, $objects ) = @_;

        my $session = $plugin->{session};
        my @problems;
	
        # character length checks...
        &ref_support_check_characters( $session, 'ref1_former_staff_contracts', $plugin, $objects, \@problems );

	# hesa check
        #my $user = $objects->{user};
        #my $ds = $user->dataset;
        #my $hesa = $user->value( 'hesa' );
        #if( defined $hesa && length( $hesa ) != 13  )
        #{
        #       my $desc = $session->html_phrase( "user_fieldname_hesa" );
        #       push @problems, { field => "hesa", desc => $session->html_phrase( 'ref_support:validate:invalid_hesa', fieldname => $desc ) };
        #}
        return @problems;
};


# Research Groups Fields
$c->{'ref'}->{'research_groups'}->{'fields'} = [qw{ code name }];

$c->{'ref'}->{'research_groups'}->{'mappings'} = {
        code => "ref_support_rg.code",
	name => "ref_support_rg.name",
};

# Research Outputs Fields
$c->{'ref'}->{'ref2_research_outputs'}->{'fields'} = [qw{ outputIdentifier webOfScienceIdentifier outputType title place publisher volumeTitle volume issue firstPage articleNumber isbn issn doi patentNumber month year url isPhysicalOutput supplementaryInformation numberOfAdditionalAuthors isPendingPublication pendingPublicationReserve isForensicScienceOutput isCriminologyOutput isNonEnglishLanguage englishAbstract isInterdisciplinary proposeDoubleWeighting doubleWeightingStatement doubleWeightingReserve conflictedPanelMembers crossReferToUoa additionalInformation doesIncludeSignificantMaterialBefore2014 doesIncludeResearchProcess doesIncludeFactualInformationAboutSignificance researchGroup openAccessStatus outputAllocation outputSubProfileCategory requiresAuthorContributionStatement isSensitive excludeFromSubmission outputPdfRequired }];

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
	"supplementaryInformation" => "ref_support_selection.supplementary_information_doi",
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
	"doesIncludeSignificantMaterialBefore2014" => "ref_support_selection.does_include_sig",
	"doesIncludeResearchProcess" => "ref_support_selection.does_include_res",
	"doesIncludeFactualInformationAboutSignificance" => "ref_support_selection.does_include_fact",
	"researchGroup" => "ref_support_selection.research_group",
	"openAccessStatus" => "ref_support_selection.open_access_status",
	"outputAllocation" => "ref_support_selection.output_allocation",
	"outputSubProfileCategory" => "ref_support_selection.output_sub_profile_cat",
	"requiresAuthorContributionStatement" => "ref_support_selection.author_statement",
	"isSensitive" => "ref_support_selection.sensitive",
	"excludeFromSubmission" => "ref_support_selection.exclude_from_submission",
	"outputPdfRequired" => "ref_support_selection.pdf_required",
};

# character limits
$c->{'ref_support'}->{'ref2_research_outputs_fields_length'} = {
	outputIdentifier => 24,
	webOfScienceIdentifier => 15,
	title => 7500,
	place => 256,
	publisher => 256,
	volumeTitle => 256,
	volume => 16,
	issue => 16,
	firstPage => 8,
	articleNumber => 32,
	isbn => 24,
	issn => 24,
	doi => 1024,
	patentNumber => 24,
	url => 1024,
	supplementaryInformation => 1024,
	pendingPublicationReserve => 24,
	englishAbstract => 7500,
	doubleWeightingStatement => 7500,
	doubleWeightingReserve => 24,
	conflictedPanelMembers => 512,
	additionalInformation => 7500,
	outputAllocation => 128,
	outputSubProfileCategory => 128,	
};
         

sub ref2021_month
{
        my( $plugin, $objects ) = @_;

        my $eprint = $objects->{eprint};

	my( $year, $month, $day ) = split(/-/, $eprint->value( "date" ) );
	return $month if defined $month;

	return undef;
}

# Research Outputs Validation
$c->{plugins}->{"Screen::REF_Support::Report::Research_Outputs"}->{params}->{validate_selection} = sub {
	my( $plugin, $objects ) = @_;

        my $session = $plugin->{session};
        my @problems;

        # character length checks...
        &ref_support_check_characters( $session, 'ref2_research_outputs', $plugin, $objects, \@problems );

	return @problems;
};

# Link between staff and outputs fields
$c->{'ref'}->{'ref2_staff_outputs'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier outputIdentifier authorContributionStatement isAdditionalAttributedStaffMember }];

$c->{'ref'}->{'ref2_staff_outputs'}->{'mappings'} = {
        "hesaStaffIdentifier" => "user.hesa",
        "staffIdentifier" => "user.staff_id",
        "outputIdentifier" => "ref_support_selection.selectionid",
        "authorContributionStatement" => "ref_support_selection.author_statement_text",
	"isAdditionalAttributedStaffMember" => "ref_support_selection.is_additional_staff",
};

# character limits
$c->{'ref_support'}->{'ref2_staff_outputs_fields_length'} = {
        staffIdentifier => 13,
	outputIdentifier => 13,
	authorContributionStatement => 7500,
};

# Link between staff and outputs validation
$c->{plugins}->{"Screen::REF_Support::Report::Staff_Outputs"}->{params}->{validate_selection} = sub {
        my( $plugin, $objects ) = @_;

        my $session = $plugin->{session};
        my @problems;

        # character length checks...
        &ref_support_check_characters( $session, 'ref2_staff_outputs', $plugin, $objects, \@problems );

        return @problems;
};
