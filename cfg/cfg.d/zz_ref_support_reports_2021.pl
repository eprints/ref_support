$c->{plugins}{"Screen::REF_Support::Report::Complete_Submission"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Research_Groups"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Current_Staff"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Former_Staff"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Former_Staff_Contracts"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Research_Outputs"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Report::Staff_Outputs"}{params}{disable} = 0;

$c->{ref_2021_reports} = [qw{ complete_submission research_groups ref1_current_staff ref1_former_staff ref1_former_staff_contracts ref2_research_outputs ref2_staff_outputs }];

# define which reports we'd like to include in the complete report (useful if you don't want to include REF4)
$c->{ref_2021_complete_reports}->{excel} = [qw{ research_groups ref1_current_staff ref1_former_staff ref1_former_staff_contracts ref2_research_outputs ref2_staff_outputs ref4 }];
$c->{ref_2021_complete_reports}->{xml} = [qw{ research_groups ref1_current_staff ref1_former_staff ref2_research_outputs ref2_staff_outputs ref4 }];

# generic function for checking the character lengths of the fields for a given report have not exceeded a maximum limit
sub ref_support_check_characters
{
        my( $session, $report, $plugin, $objects, $problems ) = @_;

	my $fields_length = $session->config( 'ref_support', $report.'_fields_length' ) || {};

	my $field_mappings = $session->config( 'ref', $report, 'mappings' );

        foreach my $key ( sort keys %{$fields_length} )
        {
		my( $ds, $ep_fieldname, $value ) = ref_support_get_value( $session, $plugin, $objects, $field_mappings, $key );

		# For fields that do not exist in the data objects, use the REF key instead.
		$ep_fieldname = $key if ( !defined( $ds ));
	
		if( EPrints::Utils::is_set( $value ) )
		{
			my $maxlen = $fields_length->{$key};
                        my $curlen = length( $value );

			if( $curlen > $maxlen )
                        {
				push @$problems, { field => $ep_fieldname, desc => $session->html_phrase( 'ref_support:validate:char_limit', fieldname => $session->make_text( $key ), maxlen => $session->make_text( $maxlen ) ) }; 
                        }
		}		
        }
}

sub ref_support_get_value
{
        my( $session, $plugin, $objects, $mapping, $key ) = @_;

        #get the value...              
        my $ds;
	my $value;
	my $ep_fieldname;

	my $ep_field = $mapping->{$key};

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

	return ( $ds, $ep_fieldname, $value );
}


# generic function for checking a research groups field, ensuring the research groups exist and there are no more than 4
sub ref_support_check_research_groups
{
        my( $session, $dataobj, $objects, $problems ) = @_;

	my $rgs = $dataobj->value( 'research_groups' );
	my $rg_ds = $session->dataset( 'ref_support_rg' );
	my $desc = $session->html_phrase( "user_fieldname_research_groups" );
	if( scalar @$rgs > 4 )
	{
		push @$problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:number_user_research_group', fieldname => $desc ) };
	}
	else # we have a valid number, so start checking each one is ok
	{
		# we need to check the RG is valid for the given uoa, so first we need a uoa...
		my $ref = ref $dataobj;
		my $uoa;
		if( $ref eq "EPrints::DataObj::User" )
		{
			$uoa = $dataobj->get_value( "ref_support_uoa" );
		}
		elsif( $ref eq "EPrints::DataObj::REF_Support_Circ" )
		{
			my $user = $objects->{user};
			$uoa = $user->get_value( "ref_support_uoa" );
		}	

		foreach my $rg ( @$rgs )
		{
			# check each rg is only a single alpha-numeric character
			if( $rg !~ m/^[a-zA-Z0-9]$/ )
			{
				push @$problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:user_research_group_code', rg => $session->make_text( $rg ) ) };
			}	

			# check an RG record exists for the UoA
			my $research_groups = EPrints::DataObj::REF_Support_Research_Group::search_by_uoa_and_code( $session, $uoa, $rg );
			if( $research_groups->count == 0 )
			{
				push @$problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:no_user_research_group', rg => $session->make_text( $rg ) ) };
			}
		}
	}
}

# Current Staff Fields
$c->{'ref'}->{'ref1_current_staff'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier surname initials dateOfBirth orcid contractedFTE researchConnection reasonsForNoConnectionStatement isEarlyCareerResearcher isOnFixedTermContract contractStartDate contractEndDate isOnSecondment secondmentStartDate secondmentEndDate isOnUnpaidLeave unpaidLeaveStartDate unpaidLeaveEndDate researchGroups }];

$c->{'ref'}->{'ref1_current_staff'}->{'mappings'} = {
        hesaStaffIdentifier => "user.hesa",
        staffIdentifier => \&ref2021_staff_id,
        surname => \&ref1a_support_surname,
        initials => \&ref1a_support_initials,
        dateOfBirth => "user.dob",
        orcid => \&ref2021_orcid,
        contractedFTE => "user.ref_fte",
        researchConnection => "user.research_connection",
        reasonsForNoConnectionStatement => \&ref2021_user_reason_no_connections,
        isEarlyCareerResearcher => \&ref2021_is_ecr,
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

# only provide if we don't have a HESA 
sub ref2021_staff_id
{
    my( $plugin, $objects ) = @_;

    my $user = $objects->{user} or return;

    if( !$user->is_set( "hesa" ) && $user->is_set( "staff_id" ) )
    {
        return $user->get_value( "staff_id" );
    }
    return undef;
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
        # or: orcid:0000-1234-1234-123X
        # or value: 0000-1234-1234-123X
        # or even: 000012341234123X
        # 
        # Borrowed from https://github.com/eprints/orcid_support/commit/4fa9c37e1de7ca7570703ddf4539c055e8a0008d (credit: John Salter)
        if( defined $orcid && $orcid =~ m/^(?:\s*(?:https?:\/\/)?orcid(?:\.org\/|:))?(\d{4}\-?\d{4}\-?\d{4}\-?\d{3}(?:\d|X))(?:\s*)$/ )
        {
            return $1;
        }
    }
    return undef;
};

# join the array of options into a string
sub ref2021_user_reason_no_connections
{
    my( $plugin, $objects ) = @_;

    my $user = $objects->{user} or return;

    if( $user->is_set( "reason_no_connections" ) )
    {
        return join ',', @{$user->get_value( "reason_no_connections" )};
    }
    return undef;
};


# only provide if we don't have a HESA 
sub ref2021_is_ecr
{
    my( $plugin, $objects ) = @_;

    my $user = $objects->{user} or return;

    if( !$user->is_set( "hesa" ) && $user->is_set( "is_ecr" ) )
    {
        return $user->get_value( "is_ecr" );
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
	&ref_support_check_research_groups( $session, $user, $objects, \@problems );

	# hesa check
        my $ds = $user->dataset;
        my $hesa = $user->value( 'hesa' );
        if( defined $hesa && length( $hesa ) != 13  )
        {
                my $desc = $session->html_phrase( "user_fieldname_hesa" );
                push @problems, { field => "hesa", desc => $session->html_phrase( 'ref_support:validate:invalid_hesa', fieldname => $desc ) };
        }

	if( !$user->is_set( "hesa" ) && !$user->is_set( "staff_id" ) )
	{
                push @problems, { field => "hesa", desc => $session->html_phrase( 'ref_support:validate:no_staff_id' ) };
	}

	# fte check
	if( $user->is_set( "ref_fte" ) )
	{
		my $fte = $user->get_value( "ref_fte" );
		my $decimal_points = length(($fte =~ /\.(.*)/)[0]);
		if( $fte > 1.0 )
		{
 	               push @problems, { field => "ref_fte", desc => $session->html_phrase( 'ref:validate_user:high_fte' ) };
		}	
		elsif( $fte >= 0.2 && $fte < 0.3 && ( !$user->is_set( "research_connection" ) && !$user->is_set( "reason_no_connections" ) ) )
		{
			push @problems, { field => "research_connection", desc => $session->html_phrase( 'ref_support:validate_user:fte_research_connection' ) };
		}	
		if( $decimal_points > 2 )
		{
 	               push @problems, { field => "ref_fte", desc => $session->html_phrase( 'ref_support:validate:fte_decimal' ) };
		}
	}

        return @problems;
};


# Former Staff Fields
$c->{'ref'}->{'ref1_former_staff'}->{'fields'} = [qw{ staffIdentifier surname initials dateOfBirth orcid excludeFromSubmission contracts }];

$c->{'ref'}->{'ref1_former_staff'}->{'hierarchical_fields'} = [qw{ contracts }];

$c->{'ref'}->{'ref1_former_staff'}->{'mappings'} = {
    staffIdentifier => \&ref2021_former_staff_staff_id,
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

# former staff should use HESAs where available, or staff ID where not (but only has the one column for these, unlike current staff where this is split over two columns
sub ref2021_former_staff_staff_id
{
    my( $plugin, $objects ) = @_;

    my $user = $objects->{user} or return;

    if( $user->is_set( "hesa" ) ) # we have a preference for HESA where available
    {
        return $user->get_value( "hesa" );
    }
    elsif( $user->is_set( "staff_id" ) ) # otherwise use the staff_id
    {
        return $user->get_value( "staff_id" );
    }
    return undef;
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
 
	# reinitialise the export plugin for future former staff records that need exporting
	$export_plugin->{ref_fields} = undef;
	$export_plugin->{ref_fields_order} = undef;
        $export_plugin->{report} = 'ref1_former_staff';
    
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

	# exclude check (should users where this is set not even feature or should the UoA Champion unset this user's UoA field?)
	if( $user->is_set( "exclude_from_submission" ) && $user->get_value( "exclude_from_submission" ) eq 'TRUE' )
	{
		my $desc = $session->html_phrase( "user_fieldname_exclude_from_submission" );
		push @problems, { field => "exclude_from_submission", desc => $session->html_phrase( 'ref_support:validate:exclude_user_from_submission', fieldname => $desc ) };
	} 

	return @problems;
};

# Former Staff Contracts Fields
$c->{'ref'}->{'ref1_former_staff_contracts'}->{'fields'} = [qw{ staffIdentifier hesaStaffIdentifier contractedFTE researchConnection reasonsForNoConnectionStatement startDate endDate isOnSecondment secondmentStartDate secondmentEndDate isOnUnpaidLeave unpaidLeaveStartDate unpaidLeaveEndDate researchGroups }];

$c->{'ref'}->{'ref1_former_staff_contracts'}->{'mappings'} = {
    staffIdentifier => \&ref2021_contract_staff_identifier,
    hesaStaffIdentifier => "user.hesa",
    contractedFTE => "ref_support_circ.ref_fte",
    researchConnection => "ref_support_circ.research_connection",
    reasonsForNoConnectionStatement => \&ref2021_circ_reason_no_connections,
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

        if( $user->is_set( "hesa" ) ) # to successfully match up with former staff table, we have a preference for HESA where available
        {
            return $user->get_value( "hesa" );
        }
        elsif( $user->is_set( "staff_id" ) ) # otherwise use the staff_id
        {
            return $user->get_value( "staff_id" );
        }
    }
    return undef;
}

# join the array of options into a string
sub ref2021_circ_reason_no_connections
{
    my( $plugin, $objects ) = @_;

    my $circ = $objects->{ref_support_circ} or return;

    if( $circ->is_set( "reason_no_connections" ) )
    {
        return join ',', @{$circ->get_value( "reason_no_connections" )};
    }
    return undef;
};


# Former Staff Contracts Validation
$c->{plugins}->{"Screen::REF_Support::Report::Former_Staff_Contracts"}->{params}->{validate_circ} = sub {
        my( $plugin, $objects ) = @_;

        my $session = $plugin->{session};
        my @problems;
	
        # character length checks...
        &ref_support_check_characters( $session, 'ref1_former_staff_contracts', $plugin, $objects, \@problems );

	# hesa check
        my $user = $objects->{user};
        my $ds = $user->dataset;
        my $hesa = $user->value( 'hesa' );
        if( defined $hesa && length( $hesa ) != 13  )
        {
               my $desc = $session->html_phrase( "user_fieldname_hesa" );
               push @problems, { field => "hesa", desc => $session->html_phrase( 'ref_support:validate:invalid_hesa', fieldname => $desc ) };
        }

	my $contract = $objects->{ref_support_circ};

	# fte check
        if( $contract->is_set( "ref_fte" ) )
        {
                my $fte = $contract->get_value( "ref_fte" );
                my $decimal_points = length(($fte =~ /\.(.*)/)[0]);
                if( $fte > 1.0 )
                {
                       push @problems, { field => "ref_fte", desc => $session->html_phrase( 'ref:validate_user:high_fte' ) };
                }
                elsif( $fte >= 0.2 && $fte < 0.3 && ( !$contract->is_set( "research_connection" ) && !$contract->is_set( "reason_no_connections" ) ) )
                {
                        push @problems, { field => "research_connection", desc => $session->html_phrase( 'ref_support:validate_user:fte_research_connection' ) };
                }
                if( $decimal_points > 2 )
                {
                       push @problems, { field => "ref_fte", desc => $session->html_phrase( 'ref_support:validate:fte_decimal' ) };
                }
        }

	# research group check
        &ref_support_check_research_groups( $session, $contract, $objects, \@problems );

        return @problems;
};


# Research Groups Fields
$c->{'ref'}->{'research_groups'}->{'fields'} = [qw{ code name }];

$c->{'ref'}->{'research_groups'}->{'mappings'} = {
    code => "ref_support_rg.code",
    name => "ref_support_rg.name",
};

# Research Outputs Fields
$c->{'ref'}->{'ref2_research_outputs'}->{'fields'} = [qw{ outputIdentifier webOfScienceIdentifier outputType title place publisher volumeTitle volume issue firstPage articleNumber isbn issn doi patentNumber month year url isPhysicalOutput supplementaryInformation numberOfAdditionalAuthors isForensicScienceOutput isCriminologyOutput isNonEnglishLanguage englishAbstract isInterdisciplinary proposeDoubleWeighting doubleWeightingStatement doubleWeightingReserve conflictedPanelMembers crossReferToUoa additionalInformation isDelayedByCovid19 covid19Statement doesIncludeSignificantMaterialBefore2014 doesIncludeResearchProcess doesIncludeFactualInformationAboutSignificance researchGroup openAccessStatus outputAllocation1 outputAllocation2 outputSubProfileCategory requiresAuthorContributionStatement isSensitive excludeFromSubmission outputPdfRequired mediaOfOutput }];

$c->{'ref'}->{'ref2_research_outputs'}->{'mappings'} = {
	"outputIdentifier" => "ref_support_selection.selectionid",
	"webOfScienceIdentifier" => "ref_support_selection.wos_id",
	"outputType" => "ref_support_selection.type",
	"title" => "eprint.title",
	"place" => \&ref2021_place,
	"publisher" => \&ref2021_publisher,
	"volumeTitle" => \&ref2_support_volumeTitle,
	"volume" => \&ref2021_volume,
	"issue" => \&ref2021_issue,
	"firstPage" => \&ref2_support_firstPage,
	"articleNumber" => \&ref2_support_article_number,
	"isbn" => \&ref2021_isbn,
	"issn" => \&ref2021_issn,
	"doi" => \&ref2021_doi,
	"patentNumber" => \&ref2_support_patentNumber,
	"month" => \&ref2021_month,
	"year" => \&ref2_support_year,
	"url" => \&ref2_support_url,
	"isPhysicalOutput" => "ref_support_selection.is_physical_output",
	"supplementaryInformation" => "ref_support_selection.supplementary_information_doi",
	"numberOfAdditionalAuthors" => \&ref2_support_additionalAuthors,
    #"isPendingPublication" => "ref_support_selection.pending",
    #"pendingPublicationReserve" => "ref_support_selection.pending_publication",
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
	"isDelayedByCovid19" => "ref_support_selection.covid_19",
	"covid19Statement" => "ref_support_selection.covid_statement",
	"doesIncludeSignificantMaterialBefore2014" => "ref_support_selection.does_include_sig",
	"doesIncludeResearchProcess" => "ref_support_selection.does_include_res",
	"doesIncludeFactualInformationAboutSignificance" => "ref_support_selection.does_include_fact",
	"researchGroup" => "ref_support_selection.research_group",
	"openAccessStatus" => \&ref2021_open_access_status,
	"outputAllocation1" => "ref_support_selection.output_allocation",
	"outputAllocation2" => "ref_support_selection.output_allocation_2",
	"outputSubProfileCategory" => "ref_support_selection.output_sub_profile_cat",
	"requiresAuthorContributionStatement" => "ref_support_selection.author_statement",
	"isSensitive" => "ref_support_selection.sensitive",
	"excludeFromSubmission" => "ref_support_selection.exclude_from_submission",
	"outputPdfRequired" => "ref_support_selection.pdf_required",
	"mediaOfOutput" => "ref_support_selection.media_of_output",
};

# character limits
$c->{'ref_support'}->{'ref2_research_outputs_fields_length'} = {
	outputIdentifier => 24,
	webOfScienceIdentifier => 20,
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
	covid19Statement => 7500,
	outputAllocation1 => 128,
	outputAllocation2 => 128,
	outputSubProfileCategory => 128,
	mediaOfOutput => 264,
};

sub ref2021_place
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $selection = $objects->{ref_support_selection};

    my $relevant_types = [ qw( L P I M S ) ];

    if( $selection->is_set( "type" ) && grep { $selection->value( "type" ) eq $_ } @{$relevant_types} )
    {
        return $eprint->value( "event_location" ) if $eprint->is_set( "event_location" );
    }
    return undef;
}


sub ref2021_publisher
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $selection = $objects->{ref_support_selection};

    my $relevant_types = [ qw( A B C G N O T U ) ];

    # for T - Other items, we actually want to provide a brief description of type here
    if( $selection->is_set( "type" ) && $selection->value( "type" ) eq 'T' )
    {
        return $selection->value( "other_desc" ) if $selection->is_set( "other_desc" );   
    }
    elsif( $selection->is_set( "type" ) && grep { $selection->value( "type" ) eq $_ } @{$relevant_types} )
    {
        return $eprint->value( "publisher" ) if $eprint->is_set( "publisher" );
    }
    return undef;
}

sub ref2021_volume
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $selection = $objects->{ref_support_selection};

    my $relevant_types = [ qw( D E ) ];

    if( $selection->is_set( "type" ) && grep { $selection->value( "type" ) eq $_ } @{$relevant_types} )
    {
        return $eprint->value( "volume" ) if $eprint->is_set( "volume" );
    }
    return undef;
}

sub ref2021_issue
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $selection = $objects->{ref_support_selection};

    my $relevant_types = [ qw( D E ) ];

    if( $selection->is_set( "type" ) && grep { $selection->value( "type" ) eq $_ } @{$relevant_types} )
    {
        return $eprint->value( "number" ) if $eprint->is_set( "number" );
    }
    return undef;
}

sub ref2021_isbn
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $selection = $objects->{ref_support_selection};

    my $relevant_types = [ qw( A B C R ) ];

    if( $selection->is_set( "type" ) && grep { $selection->value( "type" ) eq $_ } @{$relevant_types} )
    {
        return $eprint->value( "isbn" ) if $eprint->is_set( "isbn" );
    }
    return undef;
}

sub ref2021_issn
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $selection = $objects->{ref_support_selection};

    my $relevant_types = [ qw( D E ) ];

    if( $selection->is_set( "type" ) && grep { $selection->value( "type" ) eq $_ } @{$relevant_types} )
    {
        return $eprint->value( "issn" ) if $eprint->is_set( "issn" );
    }
    return undef;
}

# lifted straight from UKETD plugin (again), which is based on render_possible_doi
sub ref2021_doi
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $session = $plugin->{session};

    #start with an assumption
    my $doi_field = "id_number";
    if( EPrints::Utils::is_set( $session->get_conf( "hefce_oa","eprintdoifield" ) ) )
    {
        #a) have we defined the doi_field within the hefce_oa conf?
        $doi_field = $session->get_conf( "hefce_oa", "eprintdoifield" );
    }
    elsif( EPrints::Utils::is_set( $session->get_conf( "datacitedoi", "eprintdoifield" ) ) )
    {
        #b) have we already defined the doi_field within the dataitedoi plugin?
        $doi_field = $session->get_conf("datacitedoi","eprintdoifield");
    }

    return undef if !$eprint->is_set( $doi_field );

    my $doi = $eprint->value( $doi_field );
    if( $doi =~ m!^
         (?:https?://(?:dx\.)?doi\.org/)?  # add this again later anyway
         (?:doi:?\s*)?                   # don't need any namespace stuff
         (10(\.[^./]+)+/.+)              # the actual DOI => $1
     !ix )
     {
         # just use the last part - the actual DOI.
         return $1;
     }

    return undef;
}

sub ref2021_month
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};

    return undef if !$eprint->is_set( "date" );

    my( $year, $month, $day ) = split(/-/, $eprint->value( "date" ) );
    return $month if defined $month;

    return undef;
}

sub ref2021_open_access_status
{
    my( $plugin, $objects ) = @_;

    my $eprint = $objects->{eprint};
    my $selection = $objects->{ref_support_selection};

    if( $selection->is_set( "type" ) && $eprint->is_set( "issn" ) &&
        ( $selection->value( "type" ) eq "D" || $selection->value( "type" ) eq "E" ) )
    {
        return $selection->value( "open_access_status" );   
    }
    return undef;
}

$c->{ref_support}->{ref2_research_outputs_required_fields} = {

	"title" => [ qw( A B C D E F G H I J K L M N O P Q R S T U V ) ],
	"place" => [ qw( L P I M S ) ],
	"publisher" => [ qw( A B C G N O T U ) ],
	"volumeTitle" => [ qw( C R D E ) ],

	"articleNumber" => sub
	{
		my( $session, $eprint, $selection ) = @_;

		# "Article number" - D (if first page is not provided)

		my $potential_problem = { field => 'unused', desc => $session->html_phrase( 'ref_support:validate:required_field:articleNumber' ) };

		my $selection_type = $selection->get_value("type");

		if( $selection_type eq 'D' )
		{
			return $potential_problem unless( $eprint->is_set( 'pagerange' ) );
		}

		return 0;
	},

	"firstPage" => sub
	{
		my( $session, $eprint, $selection ) = @_;

		# "First page" - D (if article number is not provided), E

		my $selection_type = $selection->get_value("type");

		if( $selection_type eq 'D' )
		{
			return 0 if( $eprint->exists_and_set( 'article_number' ) );
			return 0 if( $selection->value( 'article_id' ) );
			return { field => 'unused', desc => $session->html_phrase( 'ref_support:validate:required_field:firstPage' ) };
		}

		if ( $selection_type eq 'E')
		{
			return { field => 'unused', desc => $session->html_phrase( 'ref_support:validate:required_field', fieldname => $session->make_text( 'firstPage' )) };
		}

		return 0;
	},

	"volume" => [ qw( D ) ],
	"isbn" => [ qw( A B C ) ],
	"issn" => [ qw( D ) ],
	"patentNumber" => [ qw ( F ) ],
	"year" => [ qw( A B C D E F G H I J K L M N O P Q R S T U V ) ],

	"month" => sub {

		my( $session, $eprint, $selection, $user ) = @_;

		my( $year, $month, $day ) = split(/-/, $eprint->value( "date" ) ) if $eprint->is_set( "date" );	
	
		# we need a month for former staff (end date before 2020-07-31)
		if( !EPrints::Utils::is_set( $month ) && $user->is_set( "ref_end_date" ) ) # check to see if a month is actually required and we have the info to perform the check
		{
			my $end_date = $user->get_value( "ref_end_date" );
			my $end_tp;		
			if( $end_date =~ /^(\d{4})/ ) # we have a year...
			{
				$end_tp = Time::Piece->strptime( "$end_date-01-01", "%Y-%m-%d" )
			}
			elsif( $end_date =~ /^(\d{4})\-\d{2}$/ ) # month and year
			{
				$end_tp = Time::Piece->strptime( "$end_date", "%Y-%m" )
			}
			elsif( $end_date =~ /^(\d{4})\-(\d{2})\-(\d{2})$/ )
			{
				$end_tp = Time::Piece->strptime( "$end_date", "%Y-%m-%d" )
			}
	
			# now compare our end date with the census date
			if( EPrints::Utils::is_set( $end_tp ) )
			{
				my $census_tp = Time::Piece->strptime( "2020-07-31", "%Y-%m-%d" );
				if( $end_tp < $census_tp ) # a month is necessary 
				{
					return { field => 'unused', desc => $session->html_phrase( 'ref_support:validate:required_field:month' ) };
				}
			}	
		}

		return 0;
	},

	"url" => [ qw( H ) ],
	"isPhysicalOutput" => [ qw( A B C E F G H I J K L M N O P Q R S T U V ) ],
};


# Research Outputs Validation
$c->{plugins}->{"Screen::REF_Support::Report::Research_Outputs"}->{params}->{validate_selection} = sub {
	my( $plugin, $objects ) = @_;

        my $session = $plugin->{session};
        my @problems;

	my $user = $objects->{user};
	my $eprint = $objects->{eprint};

	my $selection = $objects->{ref_support_selection};
	my $uoa = $selection->current_uoa;
	my( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa );

        # character length checks...
        &ref_support_check_characters( $session, 'ref2_research_outputs', $plugin, $objects, \@problems );

	# required fields checks
	my $selection_type = $selection->get_value("type");

	my $required_fields = $session->config( 'ref_support', 'ref2_research_outputs_required_fields' ) || {};
	my $field_mappings = $session->config( 'ref', 'ref2_research_outputs', 'mappings' );

        foreach my $key ( keys %{$required_fields} )
	{
		my $conditions = $required_fields->{$key};
		my $potential_problem = undef;

		if( ref( $conditions ) eq 'CODE' )
		{
			$potential_problem = &$conditions( $session, $eprint, $selection, $user );
		}
		elsif( grep { $_ eq $selection_type } @{$conditions} )
		{
			$potential_problem = { field => 'unused', desc => $session->html_phrase( 'ref_support:validate:required_field', fieldname => $session->make_text( $key )) };
		}

		if( $potential_problem )
		{
			my( $ds, $ep_fieldname, $value ) = ref_support_get_value( $session, $plugin, $objects, $field_mappings, $key );
			
			if( !EPrints::Utils::is_set( $value ) )
			{
				push @problems, $potential_problem;
			}		
		}
	}

	# year and month checks
	my( $year, $month, $day ) = split(/-/, $eprint->value( "date" ) ) if $eprint->is_set( "date" );	
	
	# check we have a valid year
	if( EPrints::Utils::is_set( $year ) && ( $year < 2014 || $year > 2020 ) )
	{
		push @problems, { field => "year", desc => $session->html_phrase( 'ref_support:validate:invalid_year' ) };
	}

	# isNonEnglishLanguage and englishAbstract
	if( $selection->is_set( "non_english" ) && $selection->get_value( "non_english" ) eq 'TRUE' )
	{
		if( !$selection->is_set( "abstract" ) )
		{
			push @problems, { field => "abstract", desc => $session->html_phrase( 'ref_support:validate:english_abstract_required' ) };
		}
	}

	# researchGroup
	if( $selection->is_set( "research_group" ) )
	{
		my $rg = $selection->get_value( "research_group" );
		if( $rg !~ m/^[a-zA-Z0-9]$/ )
                {
                	push @problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:user_research_group_code', rg => $session->make_text( $rg ) ) };
                }

                # check an RG record exists for the UoA
                my $research_groups = EPrints::DataObj::REF_Support_Research_Group::search_by_uoa_and_code( $session, $uoa, $rg );
                if( $research_groups->count == 0 )
		{
                	push @problems, { field => "research_groups", desc => $session->html_phrase( 'ref_support:validate:no_user_research_group', rg => $session->make_text( $rg ) ) };
		}
	}
	
	# additionalInformation
	if( $selection->is_set( "details" ) )
	{
		my $word_limit = 0;
		if( $selection->is_set( "does_include_sig" ) && $selection->get_value( "does_include_sig" ) eq 'TRUE' )
		{
			$word_limit = $word_limit + 100;
		}
		if( $selection->is_set( "does_include_res" ) && $selection->get_value( "does_include_res" ) eq 'TRUE' )
		{
			$word_limit = $word_limit + 300;
		}
		if( $selection->is_set( "does_include_fact" ) && $selection->get_value( "does_include_fact" ) eq 'TRUE' && ( $uoa eq "ref2021_b11" || $uoa eq "ref2021_b12" ) )
		{
			$word_limit = $word_limit + 100;
		}

		my @words = split /\s+/, $selection->get_value( "details" );
                if( @words > $word_limit )
                {
			my $desc = $session->html_phrase( "ref_support_selection_fieldname_details" );
                        push @problems, { field => "details", desc => $session->html_phrase( "ref:validate:word_limit", field => $desc, length => $session->make_text( scalar @words ), limit => $session->make_text( $word_limit ) ) };
		}
	}

	# doesIncludeFactualInformationAboutSignificance 
	if( $selection->is_set( "does_include_fact" ) && $selection->get_value( "does_include_fact" ) eq 'TRUE' && ( $uoa ne "ref2021_b11" && $uoa ne "ref2021_b12" ) )
	{
		my $desc = $session->html_phrase( "ref_support_selection_fieldname_does_include_fact" );
		push @problems, { field => "does_include_fact", desc => $session->html_phrase( 'ref_support:validate:does_include_fact_flag', fieldname => $desc, uoa => $session->make_text( $hefce_uoa_id ) ) };
	}

	# outputAllocation1
	my @output_allocation_1_requirements = ( 7, 10, 11, 12, 26, 27, 28, 29, 33, 34 );

	if( ( grep { $hefce_uoa_id eq $_ } @output_allocation_1_requirements ) && !$selection->is_set( "output_allocation" ) )
	{ 
		push @problems, { field => "output_allocation", desc => $session->html_phrase( 'ref_support:validate:output_allocation_1_required', uoa => $session->make_text( $hefce_uoa_id ) ) };
	}

	# outputAllocation2
	my @output_allocation_2_requirements = ( 26 );
	if( ( grep { $hefce_uoa_id eq $_ } @output_allocation_2_requirements ) && !$selection->is_set( "output_allocation_2" ) )
	{ 
		push @problems, { field => "output_allocation_2", desc => $session->html_phrase( 'ref_support:validate:output_allocation_2_required', uoa => $session->make_text( $hefce_uoa_id ) ) };
	}


	# exclude check (should users where this is set not even feature or should the UoA Champion unset this user's UoA field?)
    if( $selection->is_set( "exclude_from_submission" ) && $selection->get_value( "exclude_from_submission" ) eq 'TRUE' )
    {
        my $desc = $session->html_phrase( "ref_support_selection_fieldname_exclude_from_submission" );
        push @problems, { field => "exclude_from_submission", desc => $session->html_phrase( 'ref_support:validate:exclude_selection_from_submission', fieldname => $desc ) };
    }

    # double_reserve check
    if( $selection->is_set( 'double_reserve' ) )
    {
        # can't have chosen a reserved output if the current selection is not double-weighted
        if( !$selection->is_set( 'weight' ) || $selection->get_value( 'weight' ) ne 'double' )
        {
            push @problems, { field => "double_reserve", desc => $session->html_phrase( "ref_support:validate:wrong_reserve" ) };
        }

        # a selection can't be double-weighted and a reserved for itself
        if( $selection->get_value( 'double_reserve' ) eq $selection->get_id )
        {
            push @problems, { field => "double_reserve", desc => $session->html_phrase( "ref_support:validate:self_reserve" ) };
        }
    }
    else
    {
        # if the output is double weighted then it must reference a reserved output
        if( $selection->is_set( 'weight' ) && $selection->value( 'weight' ) eq 'double' )
        {
            push @problems, { field => "weight", desc => $session->html_phrase( "ref_support:validate:missing_field",
                    fieldname => $session->html_phrase( 'ref_support_selection_fieldname_reserve' )
            ) };
        }
    }

	return @problems;
};

# Link between staff and outputs fields
$c->{'ref'}->{'ref2_staff_outputs'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier outputIdentifier authorContributionStatement isAdditionalAttributedStaffMember }];

$c->{'ref'}->{'ref2_staff_outputs'}->{'mappings'} = {
    "hesaStaffIdentifier" => "user.hesa",
    "staffIdentifier" => \&ref2021_staff_id,
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
