package Genome::Site::WUGC::Finishing::Project::GSC;

use strict;
use warnings;

use base 'Genome::Site::WUGC::Finishing::Project';

use Bio::DB::GenBank;
use Data::Dumper;
use ProjectWorkBench::Model::FinishingProject::Approval;
use ProjectWorkBench::Model::FinishingProject::Digest;
use ProjectWorkBench::Model::FinishingProject::Findid;
use ProjectWorkBench::Model::FinishingProject::SubmitHashMaker;
use ProjectWorkBench::Model::FinishingProject::Report;
use ProjectWorkBench::Model::Reaction;
use File::Basename;
use File::Copy;
use Findid::Utility;
use Storable;

my %findid :name(_findid:p);
my %latin_name :name(_latin_name:p);
my %common_name :name(_common_name:p);
my %offline :name(_offline:p);

sub START
{
    my $self = shift;

    my $dir = $self->dir;

    unless ( defined $dir and -d $dir )
    {
        #$self->info_msg($self->name . " is offline, file system info will not be loaded.");
        $self->_offline(1);
        return 1;
    }

    unless ( -s $self->pwb_file_name )
    {
        my $data;
        $data->{comments} = "none";
        $data->{my_status} = "none";
        store $data, $self->pwb_file_name;
    }
    
    return 1;
}

# file system
sub dir
{
    my $self = shift;

    return if $self->_offline;
    
    return $self->proxy->consensus_abs_path;
}

sub offline
{
    my $self = shift;

    return $self->_offline;
}

sub filesystem_status
{
    my $self = shift;
    
    return "offline" if $self->_offline;
    return "online";
}

# status
sub qa_status
{
    my $self = shift;

    my $pse = $self->get_projects_last_submission_pse;

    return 'none' unless defined $pse;

    my %qa_statuses = 
    (
        3170 => 'presubmit',
        3171 => 'presubmit', # qa claim
        3172 => 'hold',
        3173 => 'approve',
        3175 => 'review_request',
        3407 => 'review_needed',
        3408 => 'review_made',
    );

    return $qa_statuses{ $pse->ps_id } if exists $qa_statuses{ $pse->ps_id };
    
    if ($pse->ps_id == 3174)
    {
        return 'reject_confirmed' if $pse->pse_status eq 'inprogress'; # reviewed by coor
        return 'reject_request'; # awaiting review by coor status should be 'new'
    }
    
    return 'none';
}   

# finishers/prefinshers
sub finisher_unix_login
{
    my $self = shift;

    my $claim_info = $self->proxy->recent_claim_info;

    return ( $claim_info ) ? $claim_info->{unix_login} : 'NA';
}

sub claim_date
{
    my $self = shift;

    my $claim_info = $self->proxy->recent_claim_info;

    return ( $claim_info ) ? $claim_info->{date} : 'NA';
}

sub prefinishers_unix_logins
{
    my ($self, @unix_logins) = @_;

    $self->prefinishers_unix_logins(\@unix_logins) if @unix_logins;

    unless (defined $self->{prefinishers_unix_logins})
    {
        unless ($self->_offline)

        {
            $self->notes_file =~ /SORTER=\s*(.+)/;
            my %sorters = map {$_, $_} split(/,\s+|\//, $1);

            $self->{prefinishers_unix_logins} = [ keys %sorters ] if %sorters;
        }
    }

    return @{ $self->prefinishers_unix_logins } if $self->prefinishers_unix_logins;
    return;
}

# organism/species/latin names
sub _set_common_and_latin_names
{
    my $self = shift;

    return 1 if $self->_latin_name and $self->_common_name;
    
    my $name = $self->name;
    my @prefixes;
    for (my $i = 2; $i <= 5; $i++)
    {
        push @prefixes, substr($name,0,$i);
    }

    my $prefix_string = join(',', map { "'$_'" } @prefixes);

    my $sth = $self->execute_sql
    (
        sql => qq/
        select o.species_name, o.species_latin_name
        from dna_resource dr
        join entity_attribute_value eav on eav.entity_id = dr.dr_id
        join organism_taxon\@dw o on o.legacy_org_id = eav.value
        where eav.attribute_name = 'org id'
        and dr.dna_resource_prefix in ($prefix_string)
        order by dr.dna_resource_prefix DESC
        /
    );

    return unless $sth;

    my ($common, $latin) = $sth->fetchrow_array;

    $self->_common_name( $common || 'unknown' );
    $self->_latin_name( $latin || $common || 'unknown' );

    return 1;
}

sub latin_name
{
    my $self = shift;
    
    return unless $self->_set_common_and_latin_names;

    return $self->_latin_name;
}

sub common_name
{
    my $self = shift;
    
    return unless $self->_set_common_and_latin_names;

    return $self->_common_name;
}

sub organism_name
{
    my $self = shift;

    return $self->latin_name;
}

sub get_projects_last_submission_pse
{
    my $self = shift; 

    my ($pse) = $self->proxy->get_projects_submission_pses;
    
    return $pse;
}

####################
## PSES 'n' Stuff ##
####################

sub get_project_pses
{
    my $self = shift;
    
    GSC::ProjectPSE->unload;

    return GSC::ProjectPSE->get(project_id => $self->project_id);
}

sub get_pse_comments
{
    my $self = shift;
    
    my @ppses = $self->get_project_pses;

    return unless @ppses;

    return GSC::PSEComment->get(pse_id => [ map { $_->pse_id } @ppses ] ); 
}

sub get_inprogress_claim_for_qa_pses
{
    my $self = shift;

    my @ppses = $self->get_project_pses;

    return unless @ppses;

    return GSC::PSE->get
    (
        pse_id => [ map { $_->pse_id } @ppses ],
        ps_id => 3171,
        pse_status => 'inprogress',
    );
}

sub get_recent_presubmit_date
{
    my $self = shift;

    my @ppses = $self->get_project_pses;

    return unless @ppses;

    my ($pse) = sort { $b->pse_id <=> $a->pse_id }
    GSC::PSE->get
    (
        pse_id => [ map { $_->pse_id } @ppses ],
        ps_id => 3170,
        pse_status => 'inprogress',
    );

    return unless defined $pse;

    return $pse->date_scheduled;
}

##############################
## Data Set in the PWB File ##
##############################

sub pwb_file_name
{
    my $self = shift;
    
    return if $self->_offline;
    
    return $self->dir . "/" . $self->name . "_pwb.stor";
}

sub fin_points
{
    my $self = shift;

    return 1 if $self->_offline;

    my $notes = $self->notes_file;

    return 1 unless defined $notes;

    my $num_of_contigs;
    if ( $notes =~ /#.*c(on)?t(i)?gs:\s*(\d+)/i )
    {
        $num_of_contigs = "$3";
    }
    else
    {

        $num_of_contigs = 1;
    }

    my $num_of_spanned;
    if ( $notes =~ /spanned:\s*(\d+)/i )
    {
        $num_of_spanned = "$1";
    }
    else
    {
        $num_of_spanned = 0;
    }

    # ctgs = 4; sp = 2; fp = 4 + (4 - 2 - 1) = 5
    my $fp = $num_of_contigs + ($num_of_contigs - $num_of_spanned - 1);

    return $fp if $fp >= 0;
}

sub base_pairs
{
    my $self = shift;

    return "UNR" if $self->_offline;

    my $acefile = $self->recent_acefile;

    my $am = $self->get_acemodel($acefile);

    return unless defined $am;

    my $af;
    if ( $self->name =~ /^Z_/i )
    {
        $af = ProjectWorkBench::Model::Ace::FormatOutput->new
        (
            format => 'bp_df',
            objects => $am->contigs_to_tags(types => ['doFinish']),
        );
    }
    else
    {
        $af = ProjectWorkBench::Model::Ace::FormatOutput->new
        (
            format => 'bp_start_end',
            objects => $am->contigs_to_tags(types => ['Annotation']),
        );
    }

    return 0 unless $af;
    
    return $af->output;
}

sub color
{
    my ($self, $color) = @_;
    
    return "offline" if $self->_offline;

    my $data = retrieve $self->pwb_file_name;

    if (defined $color)
    {
        $data->{color} = $color;
        store $data, $self->pwb_file_name;
    }
    elsif (! defined $data->{color} and defined $self->notes_file)
    {
        $self->{color} = lc $1 if $self->notes_file =~ /CLONE STATUS:.*(red|yellow|orange|green)/i;
        store $data, $self->pwb_file_name;
    }

    return $data->{color} if exists $data->{color} and defined $data->{color};
    return "unknown";
}

sub comments
{
    my ($self, $comments) = @_;

    return "offline" if $self->_offline;

    my $data = retrieve $self->pwb_file_name;

    if (defined $comments)
    {
        $data->{comments} = $comments;
        store $data, $self->pwb_file_name;
    }

    return $data->{comments} if exists $data->{comments} and defined $data->{comments};
    return "none";
}

sub priority
{
    my ($self, $priority) = @_;
    
    return 0 if $self->_offline;

    my $data = retrieve $self->pwb_file_name;

    if (defined $priority)
    {
        $data->{priority} = $priority;
        store $data, $self->pwb_file_name;
    }

    return $data->{priority} if exists $data->{priority} and defined $data->{priority};
    return 0;
}

sub my_status
{
    my ($self, $my_status) = @_;

    return "offline" if $self->_offline;

    my $qa_status = $self->qa_status;
    
    unless ( grep { $_ eq $qa_status } (qw/ none reject_confirmed /) )
    {
        return lc $qa_status;
    }
    
    my $data = retrieve $self->pwb_file_name;

    if (defined $my_status)
    {
        $data->{my_status} = $my_status;
        store $data, $self->pwb_file_name;
    }

    return $data->{my_status} if exists $data->{my_status} and defined $data->{my_status};
    return "none";
}

sub nav_status
{
    my ($self, $nav, $status) = @_;

    return 0 if $self->_offline;
    
    return unless defined $nav;

    my $data = retrieve $self->pwb_file_name;

    if (defined $status)
    {
        $data->{nav_statuses}->{$nav} = $status;
        store $data, $self->pwb_file_name;
    }

    return $data->{nav_statuses}->{$nav};
}

sub coor_review_made
{
    my $self = shift;

    my $pse = $self->get_projects_last_submission_pse;

    return $pse if $pse->ps_id == 3175 and $pse->pse_status eq 'confirming';

    return;
}

sub fin_review_made
{
    my $self = shift;

    my $pse = $self->get_projects_last_submission_pse;

    return $pse if $pse->ps_id == 3175 and $pse->pse_status eq 'confirm';

    return;
}

sub next_step
{
    my $self = shift;

    my $pse = $self->get_projects_last_submission_pse;

    return 'presubmit' if not defined $pse
        or ( $pse->ps_id == 3174 and $pse->pse_status eq 'inprogress');
    
    return 'review_made' if $pse->ps_id == 3407;

    return;
}

############
## Submit ##
############

sub create_submit_hash
{
    my ($self, $ace) = @_;

    return if $self->_offline;
    
    my $shm = ProjectWorkBench::Model::FinishingProject::SubmitHashMaker->new();

    return $shm->create_submit_hash($self);
}

sub create_submit_hash_file
{
    my ($self, $ace) = @_;

    return if $self->_offline;
    
    my $shm = ProjectWorkBench::Model::FinishingProject::SubmitHashMaker->new();

    my $sh = $shm->create_submit_hash($self);

    store $sh, $self->submit_file;

    return $sh;
}

sub submit_file
{
    my $self = shift;

    return if $self->_offline;
    
    return $self->dir . "/" . $self->name . ".serialized.dat";
}

###############
## Checklist ##
###############

sub checklist
{
    my $self = shift;
    
    return ProjectWorkBench::Model::FinishingProject::Checklist->new(project => $self);
}

sub checklist_stats
{
    my $self = shift;

    return $self->checklist->stats;
}

sub checklist_navigations
{
    my $self = shift;

    return $self->checklist->navigations;
}

sub check
{
    my $self = shift;

    my $next_step = $self->next_step;

    return "Project not eligible for submission" if $next_step =~ /^na/i;
   
    # Do not check if next step is change_(re)presubmit
    return if $next_step =~ /change/i;

    # Check navs
    my @navs = $self->checklist_navigations;
    
    my $navs_pressed = grep { $self->nav_status($_) } $self->checklist_navigations;

    return "Not all navigation buttons pressed" unless $navs_pressed == scalar @navs;
    
    return $self->checklist->check_project;
}

############
## Findid ##
############

sub parsefindid
{
    my $self = shift;

    return if $self->_offline;
    
    return $self->dir . "/findid/parsefindid";
}

sub findid
{
    my $self = shift;

    return if $self->_offline;

    return unless -s $self->parsefindid;

    unless ( $self->_findid )
    {
        $self->_findid
        (
            ProjectWorkBench::Model::FinishingProject::Findid->new
            (
                project_name => $self->name,
                species => Findid::Utility->convert_GSC_to_DB($self->species_name),
                file => $self->parsefindid,
            )
        );
    }

    return $self->_findid;
}

sub findid_age
{
    my $self = shift;

    return if $self->_offline;

    return ( $self->findid )
    ? $self->findid->age
    : -1;
}

sub findid_db
{
    my $self = shift;

    my $org  = Findid::Utility->convert_GSC_to_DB($self->species_name);

    return "$org,bacterial";
}

################
## Notes File ##
################

sub notes_file_name
{
    my $self = shift;

    return $self->dir . "/" . $self->name . ".notes";
}

sub notes_file
{
    my ($self, $notes) = @_;

    return if $self->_offline;
    
    my $fh = IO::File->new("< ". $self->notes_file_name);
    
    if ($fh)
    {
        return join ("", $fh->getlines);
    }
    
    return;
}

####################
## Priority Array ##
####################

sub priority_array
{
    return (qw/0 1 2 3 4 5 6 7 8 9/);
}

###############
## Approvals ##
###############

sub approval_types
{
    return sort (qw/ambiguous_base digests iverted_repeat tandem duplication ssr single_digest unknown/);
}

sub get_num_for_approval_type
{
    my ($self, $type) = @_;

    return 0 unless defined $type;
    
    my @types = $self->approval_types;

    for (my $i = 0; $i <= $#types; $i++)
    {
        return $i if $type eq $types[$i];
    }
}

sub approvals
{
    my $self = shift;

    return if $self->_offline;

    my $data = retrieve $self->pwb_file_name;

    if ( $data->{approvals} )
    {
        $data->{approvals} = [ sort { $a->id <=> $b->id } @{ $data->{approvals} } ];
        store $data, $self->pwb_file_name;
        return @{ $data->{approvals} } 
    }

    return;
}

sub push_approval
{
    my ($self, $app) = @_;

    my $data = retrieve $self->pwb_file_name;
 
    if (defined $app)
    {
        push @{ $data->{approvals} }, $app;
        $data->{approvals} = [ sort { $a->id <=> $b->id } @{ $data->{approvals} } ];
        store $data, $self->pwb_file_name;
        return $app;
    }

    return;
}

sub splice_approval
{
    my ($self, $offset) = @_;
    
    my $data = retrieve $self->pwb_file_name;

    my $app = splice(@{ $data->{approvals} }, $offset, 1);

    if (defined $app)
    {
        $data->{approvals} = [ sort { $a->id <=> $b->id } @{ $data->{approvals} } ];
        store $data, $self->pwb_file_name;
        return $app;
    }

    return;
}

sub splice_approval_by_id
{
    my ($self, $id) = @_;
    
    my $data = retrieve $self->pwb_file_name;

    my $offset = 0;
    foreach my $app ( $self->approvals )
    {
        last if $app->id eq $id;
        $offset++;
    }
        
    my $app = splice(@{ $data->{approvals} }, $offset, 1);

    if (defined $app)
    {
        $data->{approvals} = [ sort { $a->id <=> $b->id } @{ $data->{approvals} } ];
        store $data, $self->pwb_file_name;
        return $app;
    }

    return;
}

sub add_approval
{
    my $self = shift;

    return if $self->_offline;

    my $id = 0;
    foreach my $app ( $self->approvals )
    {
        last if $id ne $app->id;
        $id++;
    }

    my $app =  ProjectWorkBench::Model::FinishingProject::Approval->new
    (
        project_name => $self->name,
        id => $id,
        type => "unknown"
    );

    return $self->push_approval($app);
}

sub remove_approval
{
    my ($self, $offset) = @_;

    return if $self->_offline;

    my $app = $self->splice_approval($offset);
    
    return unless defined $app;

    # Need to fix 
    #if (defined $app->coor_comments_pse_id)
    #{
    #    my $p_pse = GSC::ProjectPSE->get(project_id => $self->project_id, pse_id => $app->coor_comments_pse_id);
    #    $p_pse->delete;
    #
    #   my $pse_c = GSC::PSEComment->get(pse_id => $app->coor_comments_pse_id);
    #   $pse_c->delete;
    #
    #   my $tpp_pse = GSC::TppPSE->get();
    #   $tpp_pse->delete;
    #
    #   my $pse = GSC::PSE->get(pse_id => $app->coor_comments_pse_id);
    #   $pse->delete;
    #}

    return $app;
}

sub edit_approval
{
    my ($self, $id, $attr, $value) = @_;

    my $data = retrieve $self->pwb_file_name;

    my $app = $self->splice_approval_by_id($id);
    
    return unless $app;
    
    $app->$attr($value);

    return $self->push_approval($app);
}

sub edit_approvals_coor_comments
{
    my ($self, $ei_id, $app, $comments) = @_;

    if (defined $app->coor_comments_pse_id)
    {
        my $pse = GSC::PSEComment->get(pse_id => $app->coor_comments_pse_id);
        $pse->ei_id($ei_id);
        $pse->notes($comments);
        $pse->note_date( App::Time->now );

        return ($app->coor_comments_pse_id, $comments);
    }
    else
    {
        $comments =
        "Info     : " . $self->name . " " .  $app->id . " " . $app->type . "\n" .
        "Comment  :\n$comments\n";

        my $tp = GSC::TransferPattern->get(transfer_name => 'no transfer');

        my $ps = GSC::ProcessStep->get
        (
            process_to => 'project comment',
            group_name => 'berg',
            purpose => 'Finishing'
        );

        my $pse = $ps->execute
        (
            comment => $comments,
            tp_id => $tp->tp_id,
            project_id => $self->project_id
        );

        return ($pse->pse_id, $comments);
    }

    return;
}

sub approved_for_single_digest
{
    my $self = shift;

    return if $self->_offline;

    foreach my $app ( $self->approvals )
    {
        return 1 if defined $app->type and $app->type eq "single_digest" and $app->coor_app;
    }
    
    return;
}

#########################
# Coordinator Comments ##
#########################

# OLD
sub get_coordinator_comments
{
    my $self = shift;

    my $project_name = $self->name;

    my $sql =
    qq/
    select pc.note_date, gu.unix_login, pc.notes from projects p 
    join projects_pses pp on pp.project_project_id = p.project_id 
    join pse_comments pc on pc.pse_pse_id = pp.pse_pse_id
    join employee_infos ei on ei.ei_id = pc.ei_ei_id 
    join gsc_users gu on gu.gu_id = ei.gu_gu_id
    where p.name = ?
    order by pc.note_date
    /;

    my $dbh = App::DB->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute($project_name);

    my $ccomments;
    while (my (@array) = $sth->fetchrow_array)
    {
        $ccomments .= join ("\n", @array);
        $ccomments .= "\n***************************************\n"; 
    }

    return $ccomments;
}

sub add_coordinator_comment
{
    my ($self, $comment) = @_;

    my $tp = GSC::TransferPattern->get(transfer_name => 'no transfer');

    my $ps = GSC::ProcessStep->get
    (
        process_to => 'project comment',
        group_name => 'berg',
        purpose => 'Finishing'
    );

    my $pse = $ps->execute
    (
        comment => $comment,
        tp_id => $tp->tp_id,
        project_id => $self->project_id
    );

    return $pse;
}


###############################
## Pal and Printrepeat Files ##
###############################

sub get_pals_and_prs
{
    my $self = shift;

    return if $self->_offline;

    my $path = $self->dir . "/edit_dir/overlaps/";

    my @files = grep { $_ !~ /positions|align/ } glob("$path/*.pal*"), glob("$path/*.pr*");

    return @files;
}

##############
# FragSizes ##
##############

sub fragsizes
{
    my $self = shift;

    return if $self->_offline;

    my $path = $self->dir;
    my @fragsizes;

    foreach my $file ( glob("$path/edit_dir/fragSizes*") )
    {
        next if -l $file;

        my $fh = IO::File->new("< $file") 
            or $self->error_msg("Could not open file:\n$file\n$!");

        my $digests = join("", $fh->getlines);
        $fh->close;

        my $file_name = basename($file);
        $file_name =~ s/fragSizes//;

        foreach my $digest ( split(/\n\-1/, $digests) )
        {
            $digest =~ s/\>(.+)\n//;
            my $enzyme = lc $1;

            if ($digest =~ /\d+/)
            {
                chomp $digest;
                $digest =~ s/^\n+//;
                $digest =~ s/^\s+//;

                push @fragsizes, ProjectWorkBench::Model::FinishingProject::Digest->new
                (
                    enzyme => $enzyme,
                    info => $digest,
                    name => $file_name,
                    file => $file
                );
            }
        }
    }

    return @fragsizes;
}

#############
## Digests ##
#############

sub digests
{
    my $self = shift;

    return if $self->_offline;

    my $name = $self->name;
    my $path = $self->dir;
    my @digests;

    my @sizes = map { s/\.sizes//; ($_) = &fileparse($_) } glob ("$path/digest/*sizes");
    chomp @sizes;
    push @sizes, "hindiii.mapping";

    foreach my $suffix (@sizes)
    {
        foreach my $file ( glob("$path/digest/$name*$suffix*") )
        {
            chomp $file;
            my ($file_name) = basename($file);

            my $fh = IO::File->new("< $file");
            my $digest = join ("", $fh->getlines);
            $fh->close;

            push @digests, ProjectWorkBench::Model::FinishingProject::Digest->new
            (
                enzyme => lc $suffix,
                info => $digest,
                name => $file_name,
                file => $file
            );
        }
    }

    return @digests;
}

#############
## makecon ##
#############

sub makecon
{
    my $self = shift;
    
    my $bioseqs;
    if ( $self->_offline )
    {
        my $gb = Bio::DB::GenBank->new();
        $bioseqs = [ $gb->get_Seq_by_acc( $self->acc ) ];
    }
    else
    {
        my $am = $self->get_acemodel( $self->recent_acefile );

        return unless defined $am;

        $bioseqs = $am->contigs_to_bioseqs,
    }

    $self->error_msg("Could not makecon for " . $self->name)
        and return unless $bioseqs;

    map { $_->display_id( join('.', $self->name, $_->display_id ) ) } @$bioseqs;
    
    my $aceout = ProjectWorkBench::Model::Ace::FormatOutput->new
    (
        objects => $bioseqs,
        format => 'fasta',
    );

    return $aceout->output;
}

#################
## Pcop Report ##
#################

sub pcop_report_file
{    
    my $self = shift;
    
    my $dir = $self->dir;

    return unless $dir;
    
    return $dir . "/" . $self->name . ".pcop.stor";
}

sub create_report
{
    my $self = shift;
    
    my $report = $self->get_report;

    $self->error_msg($self->name . ' has an active report, cannot create a new one')
        and return 1 if $report;#and not $report->is_committed;
    
    return ProjectWorkBench::Model::FinishingProject::Report->new
    (
        project_name => $self->name,
        file => $self->pcop_report_file,
        finisher => $self->finisher_unix_login,
        status => 'none'
    );
}

sub get_report
{
    my $self = shift;

    my $file = $self->pcop_report_file;

    return unless -e $file;

    return ProjectWorkBench::Model::FinishingProject::Report->load($file);
}

sub archive_report
{
    my $self = shift;
    
    return if $self->_offline;

    my $report = $self->get_report;

    $self->error_msg("No pcop report for " . $self->name)
        and return unless $report;

    my $data = retrieve $self->pwb_file_name;

    push @{ $data->{_archived_reports} }, $report;

    store $data, $self->pwb_file_name;

    unlink $report->file if -e $report->file;
    
    return $report;
}

sub get_archived_reports
{
    my $self = shift;

    return if $self->_offline;

    my $data = retrieve $self->pwb_file_name;

    return unless exists $data->{_archived_reports};

    my @reports;
    foreach my $report ( @{ $data->{_archived_reports} } )
    {
        $report->_add_attributes;
        $report->_archived(1);
        push @reports, $report;
    }

    return @reports;
}

sub recover_archived_report
{
    my ($self, $index) = @_;

    return if $self->_offline;
    
    my $data = retrieve $self->pwb_file_name;

    $self->error_msg("No reports to recover for " . $self->name)
        and return unless exists $data->{_archived_reports};
    
    $self->error_msg("Invalid index to recover report: $index")
        and return unless defined $data->{_archived_reports}->[$index];
    
    my $report = splice @{ $data->{_archived_reports} }, $index, 1;

    unlink $self->pcop_report_file if -e $self->pcop_report_file;

    store $report, $self->pcop_report_file;

    store $data, $self->pwb_file_name;
    
    return $report;
}

1;
=pod

=head1 Name

 ProjectWorkBench::Model::FinishingProject

=head1 Synopsis

=head1 Usage

 ProjectWorkBench::Model::FinishingProject->new(name => 'M_BB0392D19');

 > project must be a GSC::Project

=head1 Methods

=head2 proxy

=head2 project_id

=head2 path

=head2 acc

=head2 project_status

=head2 qa_status

=head2 estimated_size

=head2 estimated_size_from_ctgs

=head2 finisher_unix_login

=head2 prefinishers_unix_logins

=head2 claim_date

=head2 neighbors

=head2 neighbor_names

=head2 plates

=head2 organism_name

=head2 species_name

=head2 chromosome

=head2 consensus_abs_path

=head2 get_projects_submission_pses

=head2 get_projects_last_submission_pse

=head2 get_ei_for_unix_login

=head2 get_ei_id_for_unix_login

=head2 finisher_group

=head2 get_project_pses

=head2 get_pse_comments

=head2 get_inprogress_claim_for_qa_pses

=head2 get_recent_presubmit_date

=head2 pwb_file_name

=head2 fin_points

=head2 base_pairs

=head2 color

=head2 comments

=head2 priority

=head2 my_status

=head2 nav_status

=head2 coor_review_made

=head2 fin_review_made

=head2 next_step

=head2 create_submit_hash

=head2 create_submit_hash_file

=head2 submit_file

=head2 ace_path

=head2 acedir

=head2 recent_ace

=head2 recent_acefile

=head2 num_of_aces

=head2 all_aces

=head2 get_aceobject

=head2 get_recent_aceobject

=head2 get_acemodel

=head2 checklist

=head2 checklist_stats

=head2 checklist_navigations

=head2 check

=head2 parsefindid

=head2 findid

=head2 findid_age

=head2 findid_db

=head2 offline

=head2 filesystem_status

=head2 notes_file_name

=head2 notes_file

=head2 priority_array

=head2 approval_types

=head2 get_num_for_approval_type

=head2 approvals

=head2 push_approval

=head2 splice_approval

=head2 splice_approval_by_id

=head2 add_approval

=head2 remove_approval

=head2 edit_approval

=head2 edit_approvals_coor_comments

=head2 approved_for_single_digest

=head2 get_coordinator_comments

=head2 add_coordinator_comment

=head2 get_pals_and_prs

=head2 fragsizes

=head2 digests

=head2 makecon

=head2 pcop_report_file

=head2 create_report

=head2 get_report

=head2 archive_report

=head2 get_archived_reports

=head2 recover_archived_report

=head1 Disclaimer

 Copyright (C) 2006-2007 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/GSC.pm $
#$Id: GSC.pm 29849 2007-11-07 18:58:55Z ebelter $
