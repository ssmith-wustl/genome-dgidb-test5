# GSC Standard environment application exports to its modules.
# Copyright (C) 2004 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package GSCApp;

=pod

=head1 NAME

GSCApp - Configuration module for GSC applications and modules

=head1 SYNOPSIS

  use GSCApp;
  App->init;

=head1 DESCRIPTION

The B<GSCApp> module uses the App* modules, and sets up a GSC-specific
default configuration.  In many ways, it is like a C #include file.

Functions in it will rarely be called.  It is "used" mostly for the code 
which executes at import time.  View the module source and read 
documentation within to see the GSC-specific configuration.

B<GSCApp> makes the following customizations to applications:

=over 4

=cut

use warnings;
use strict;
our $VERSION = 1.6;

=pod

=item *

Windows applications explicitly set ORACLE_HOME and PATH.  The application will
still need to do a "use lib" to get to GSCApp in the first place.  It will then 
use the Oracle drivers on the application server.

=cut

BEGIN {
    if ($^O eq 'MSWin32') {
        $ENV{ORACLE_HOME} = '\\\\winsvr.gsc.wustl.edu\\gsc\\pkg\\oracle\\installed';
        $ENV{PATH} = '\\\\winsvr.gsc.wustl.edu\\gsc\\pkg\\oracle\\installed\\BIN;' . $ENV{PATH};
    }
}

use App;
use GSC::Processable;
use base qw(App::MsgLogger);

=pod

=item *

GSC Sun workstations have the /gsc applications server directories later in 
the path than local directories.  This causes problems when calling Unix tools,
and is primarily there for users running legacy apps like Sun awk.

Within perl scripts, the path is corrected to the app-server-first default
used elsewhere in the lab.  Applications which shell-out to run Unix commands
can rely on a common, cross-platform, GNU-standard implimentation of tools like
awk, diff, grep, etc.

=item *

Different versions of Perl used at the GSC have the DBD::Oracle module
built against different versions of the Oracle client libraries.  The
Oracle environment variables are modified to ensure they are pointing
to the correct Oracle installation for the version of Perl you are
running.

=cut

use GSCApp::ENV;

=pod

=item *

Error and warning messages fire a callback which print ERROR:* or
WARNING:* to STDERR, producing GNU-compliant messages.  These can be
replaced in non-text applications with callbacks to update a user interface
status bar, or produce message boxes, etc.

=cut


App::MsgLogger->message_callback
(
    'status',  
    sub 
    { 
        my $msg = $_[0]->text; 
        chomp $msg; 
        print STDERR App::Name->pkg_name . ": $msg\n" if App::Debug->level; 
        return 1; 
    }
);

App::MsgLogger->message_callback
(
    'warning', 
    sub 
    { 
        my $msg = $_[0]->text; 
        chomp $msg; 
        print STDERR App::Name->pkg_name . ": WARNING: " . join(': ', (caller(2))[0, 2]) . ": $msg\n"; 
        return 1
    }
);

App::MsgLogger->message_callback
(
    'error',   
    sub 
    { 
        my $msg = $_[0]->text; 
        chomp $msg; 
        print STDERR App::Name->pkg_name . ": ERROR: " . join(': ', (caller(2))[0, 2]) . ": $msg\n"; 
        return 0
    }
);

=pod

=item *

Sets the default support email address to
E<lt>software@watson.wustl.eduE<gt>.

=cut

# set the default support email address for the GSC
App::Name->support_email('software@watson.wustl.edu');

=pod

=item *

Sets the application installation prefix to F</gsc/scripts> and treats
requests for var directory correctly.

=cut

use GSCApp::Path;

=pod

=item *

The database handles returned by App::DB (and direct calls to
App::DBI), are extended with GSC-specific methods.  See GSCApp::DBI
for more details.

=cut

use GSCApp::DBI;

=pod

=item *

GSCApp uses GSCApp::FTP to allow for uploading of directories to the
GSC FTP server.

=cut

use GSCApp::FTP;

=pod

=item *

GSCApp customizes App::Mail for use at our site.  Allowing a single,
uniform means to send electronic mail from all Perl applications.

=cut

use GSCApp::Mail;

=pod

=item *

App::Print is extended to support printing of barcodes on barcode
printers.

=cut

use GSCApp::Print::Barcode;

=pod

=item *

GSCApp::QLock implements our complex locking system for our custom
queues.  See GSCApp::QLock(3) for more information.

=cut

use GSCApp::QLock;

=pod

=item *

GSCApp::ABI holds a set of functions that can be used to communicate
with GSC ABI machines through the smbclient program

=cut

use GSCApp::ABI;

=pod

=item *

A vocabulary set is specified to help autogenerated text.  This
includes the autogeneration of class names.

The following vocabulary is specified to control the setting of case
when words are paresd:

    GSC DNA NCBI FPC ID ABI SCF GB PSE MD PCR cDNA mRNA tRNA QStat ZTR NIH NHGRI MP FTP IPR HTMP QA AB1
    
=cut


App::Vocabulary->vocabulary(qw/GSC DNA NCBI FPC ID ABI SCF GB PSE MD PCR cDNA mRNA tRNA QStat ZTR NIH NHGRI MP FTP IPR HTMP QA AB1 ETL OLTP OLAP NSF CDS UTR SFF TA/);

=pod

=item *

We override the default formula for producing table name to package
associations in four cases.

 PROCESS_STEP_EXECUTIONS        => GSC::PSE
 SEQUENCED_DNAS                 => GSC::SeqDNA
 GSC_USERS                      => GSC::User
 QSTATS                         => GSC::QStat
 BARCODE_SOURCES                => GSC::Barcode

=cut

%App::DB::type_name_override_for_table_name =
(
    PROCESS_STEP_EXECUTIONS     => 'pse',
    SEQUENCED_DNAS              => 'seq dna',
    GSC_USERS                   => 'user', 
    DNA_TYPE                    => 'dna type',
    BARCODE_SOURCES             => 'barcode',
    BARCODE                     => 'barcode new',
    TP_ENTRY                    => 'tp entry',
    SEQUENCE_VERIFICATION       => 'verification sequence tag',
    SEQUENCE_CLIPPING           => 'clipping sequence tag',
    SEQUENCE_FINISHING_TAG      => 'finishing sequence tag',    
    EXPUNGED_SEQUENCE_READ      => 'sequence expunged read',
    NHGRI_READ_FUNDING_CATEGORY => 'old nhgri read funding category',
    CDS_SEQUENCE_TAG            => 'cds sequence tag',
    SAMPLE_GAP_SEQUENCE_TAG     => 'sample coverage gap sequence tag',
    GSC_RUN                     => 'run',
    SEQUENCE_SET                => 'sequence transparent set',
    RUN_REGION_454		=> '454 run region',
);



=pod

=item *

We override the default formula for producing table name to package
associations in four cases.

 PROCESS_STEP_EXECUTIONS        => GSC::PSE
 SEQUENCED_DNAS                 => GSC::SeqDNA
 GSC_USERS                      => GSC::User
 QSTATS                         => GSC::QStat
 BARCODE_SOURCES                => GSC::Barcode

=cut

%App::DB::package_for_table_name =
(
    qw/
        PROCESS_STEP_EXECUTIONS         GSC::PSE
        SEQUENCED_DNAS                  GSC::SeqDNA
        GSC_USERS                       GSC::User
        QSTATS                          GSC::QStat
        DNA_TYPE                        GSC::DNAType
        BARCODE_SOURCES                 GSC::Barcode
        GSC_RUN                         GSC::Run
        ENTITY_TYPE                     App::Object::Class
        ENTITY_TYPE_ATTRIBUTE           App::Object::Property
        ENTITY_TYPE_ID                  App::Object::Property::ID
        ENTITY_TYPE_UNIQUE_ATTRIBUTE    App::Object::Property::Unique
        BARCODE                         GSC::BarcodeNew
        PS_TPP                          GSC::PSTPP

         
        SEQUENCE_ITEM_TYPE              GSC::Sequence::ItemType
        SEQUENCE_TAG_TYPE               GSC::Sequence::TagType
         
        SEQUENCE_FASTA_QUAL		GSC::Sequence::Fasta::Qual
        SEQUENCE_FASTA_SEQ		GSC::Sequence::Fasta::Seq

        SEQUENCE_ITEM                   GSC::Sequence::Item                
        SEQUENCE_ASSEMBLY               GSC::Sequence::Assembly
        SEQUENCE_ASSEMBLY_SANGER        GSC::Sequence::Assembly::Sanger
        SEQUENCE_ASSEMBLY_454           GSC::Sequence::Assembly::454
        SEQUENCE_ASSEMBLY_SOLEXA        GSC::Sequence::Assembly::Solexa
        SEQUENCE_ASSEMBLY_INPUT         GSC::Sequence::Assembly::Input
        SEQUENCE_ASSEMBLY_INPUT_SANGER  GSC::Sequence::Assembly::Input::Sanger
        SEQUENCE_ASSEMBLY_INPUT_454     GSC::Sequence::Assembly::Input::454
        SEQUENCE_ASSEMBLY_INPUT_Solexa  GSC::Sequence::Assembly::Input::Solexa
        SEQUENCE_ASSEMBLY_OUTPUT        GSC::Sequence::Assembly::Output
        SEQUENCE_ASSEMBLY_OUTPUT_SANGER GSC::Sequence::Assembly::Output::Sanger
        SEQUENCE_ASSEMBLY_OUTPUT_454    GSC::Sequence::Assembly::Output::454
        SEQUENCE_ASSEMBLY_OUTPUT_Solexa GSC::Sequence::Assembly::Output::Solexa
        SEQUENCE_REFERENCE_ALIGNMENT    GSC::Sequence::ReferenceAlignment
        SEQUENCE_READ                   GSC::Sequence::Read
        SEQUENCE_TEMPLATE               GSC::Sequence::Template
        
        SEQUENCE_BASE_STRING            GSC::Sequence::BaseString        
        SEQUENCE_QUALITY_STRING         GSC::Sequence::QualityString                
        SEQUENCE_PHD                    GSC::Sequence::PHD
        SEQUENCE_POLY                   GSC::Sequence::Poly
        SEQUENCE_AB1                    GSC::Sequence::AB1
        SEQUENCE_PSE                    GSC::Sequence::PSE        
        SEQUENCE_ACE                    GSC::Sequence::Ace
        SEQUENCE_ACE_FSPATH             GSC::Sequence::AceFSPath
        SEQUENCE_BLASTDB_FSPATH         GSC::Sequence::BlastDBFSPath
        SEQUENCE_POSITION               GSC::Sequence::Position
        SEQUENCE_POSITION_PAD           GSC::Sequence::PositionPad        
        SEQUENCE_CORRESPONDENCE         GSC::Sequence::Correspondence
        SEQUENCE_REVISION               GSC::Sequence::Revision
        EXPUNGED_SEQUENCE_READ          GSC::Sequence::ExpungedRead
 
        SEQUENCE_TAG                    GSC::Sequence::Tag
        SEQUENCE_TAG_RELATIONSHIP       GSC::Sequence::Tag::Relationship
        SEQUENCE_TAG_TEXT               GSC::Sequence::Tag::Text

        SEQUENCE_CLIPPING               GSC::Sequence::Tag::Clipping
        SEQUENCE_VERIFICATION           GSC::Sequence::Tag::Verification
        SEQUENCE_FINISHING_TAG          GSC::Sequence::Tag::Finishing
        CDS_SEQUENCE_TAG                GSC::Sequence::Tag::CDS
        SAMPLE_GAP_SEQUENCE_TAG         GSC::Sequence::Tag::SampleCoverageGap

        SEQUENCE_SET                    GSC::Sequence::TransparentSet
        
        SEQUENCE_READ_STAT_REF_ALIGN    GSC::Sequence::Read::Stat::RefAlign
        
        SETUP_PROJECT                   GSC::Setup::Project
        SETUP_PROCESS_PARAM		GSC::Setup::ProcessParam
        SETUP_PROJECT_TYPE              GSC::Setup::ProjectType
        SETUP_PROJECT_HTMP              GSC::Setup::Project::HTMP 
        SETUP_PROJECT_HTMP_REFSEQ       GSC::Setup::Project::HTMP::RefSeq 
        SETUP_PROJECT_HTMP_AMPLICON     GSC::Setup::Project::HTMP::Amplicon 
        SETUP_PROJECT_FINISHING         GSC::Setup::Project::Finishing

        SETUP_PIPELINE                   GSC::Setup::Pipeline
        SETUP_PIPELINE_TYPE              GSC::Setup::PipelineType
        SETUP_PIPELINE_AMPLIFICATION     GSC::Setup::Pipeline::Amplification 
        SEQUENCE_ANNOTATION_PARAM        GSC::Setup::SequenceAnnotationParam

        SETUP_AUTO_ASSEMBLY             GSC::Setup::AutoAssembly
        SETUP_BASECALLER                GSC::Setup::Basecaller
        SETUP_AMPLICON_DESIGN           GSC::Setup::AmpliconDesign
        SETUP_SEQUENCE_ANNOTATION       GSC::Setup::SequenceAnnotation
        READ_SUBMISSION_NCBI            GSC::Sequence::Read::Submission::NCBI

        TMP_ORGANISM                    GSC::TmpOrganism
        ORGANISM_TAXON                  GSC::Organism::Taxon
        ORGANISM_SAMPLE                 GSC::Organism::Sample
        ORGANISM_SUBMISSION_ID          GSC::Organism::SubmissionID
        PHENOTYPE_MEASURABLE            GSC::Phenotype::Measurable
        PHENOTYPE_MEASUREMENT           GSC::Phenotype::Measurement
        PHENOTYPE_TRAIT                 GSC::Phenotype::Trait
        PHENOTYPE_SAMPLE_TRAIT          GSC::Phenotype::SampleTrait
        PHENOTYPE_GENERALIZATION        GSC::Phenotype::Generalization

	RUN_REGION_454			GSC::RunRegion454
	
	SEQUENCE_ASSEMBLY_METRIC_454	GSC::Sequence::Assembly::Metric::454
        VARIATION_SEQUENCE_TAG          GSC::Sequence::Tag::Variation
        VARIATION_SEQUENCE_TAG_TSCRIPT  GSC::Sequence::Tag::Variation::Tscript
        VARIATION_SEQUENCE_TAG_ALLELE   GSC::Sequence::Tag::Variation::Allele
    
    /
);

%App::DB::table_name_for_package = reverse (%App::DB::package_for_table_name);


=pod

=item *

We override the default formula for producing property
names for autogenerated classes in one case.

    READ_EXP_SEQUENCE.SEQUENCE              sequence_gzip               the sequence property returns the uncompressed version
    READ_EXP_QUALITY.QUALITY                quality_gzip                the quality property returns the uncompressed version
    SEQUENCING_SETUP.SEQUENCING_SETUP_ID    sequencing_setup_id         the naming logic doesn't catch this one automatically
    SUBMISSION_PREV_ACC.ACC_ACC_NUMBER      acc_number                  no foreign key?

=cut

%App::DB::table_column_property_name_override =
(
    qw/
        READ_EXP_SEQUENCE.SEQUENCE                  sequence_gzip
        READ_EXP_QUALITY.QUALITY                    quality_gzip
        SEQUENCING_SETUP.SEQUENCING_SETUP_ID        sequencing_setup_id
        SUBMISSION_PREV_ACC.ACC_ACC_NUMBER          acc_number
        SEQUENCED_DNAS.SUB_SUB_ID                   sub_id
        TRANSFER_PATTERN_DETAIL.DEST_DL_ID          dest_dl_id
        CHEMICAL_REAGENT_INFOS.RI_BS_BARCODE        reagent_barcode
        CHEMICAL_REAGENT_INFOS.CI_BS_BARCODE        chemical_barcode
        CLONE_GROWTHS.CG_CG_ID                      obsolete_cg_id
        SEQUENCING_SETUP.SEQUENCING_SETUP_ID        sequencing_setup_id
        CLONE_PREFIXES.HOS_HOST_NAME                host_name
        CLONE_PREFIXES.ORG_ORGANISM_NAME            organism_name
        RECIPES.CN_CHEMICAL_NAME                    chemical_name
        TP_OVERLAP.STATUS                           verification_status
        TP_ENTRY.STATUS                             tp_status
        CLONES.CLOPRE_CLONE_PREFIX                  clone_prefix
        CLONE_HISTORIES.CLOPRE_CLONE_PREFIX         clone_prefix        
        EXPUNGED_READ.FSS_FILE_SYSTEM_STATUS        file_system_status
        EXPUNGED_READ.PFT_PASS_FAIL_TAG             pass_fail_tag             
    /
);

=pod

=item *

The App::DB->local_cache_base_path is set to /tmp/app_object_cache.
The App::DB->network_cache_base_path is set to
/home200/sysman/scott/app_obj_cache.

The former is used directly by the applications running on the local
machine.  The later is updated nightly via cron job and is used to
update the former.

=cut

if ($^O eq 'MSWin32')
{
    App::DB->network_cache_base_path("//winsvr.gsc.wustl.edu/var/cache/app_object_cache_v3");
    App::DB->local_cache_base_path("c:/temp/app_object_cache_v3");
}
else
{
    App::DB->network_cache_base_path("/gsc/var/cache/app_object_cache_v3");
    App::DB->local_cache_base_path("/tmp/app_object_cache_v3");
}

=pod

=item *

Certain table columns are hiddedn such that they do not yield property
entries in the ->property_names list.  There are still property functions
for both the property name (all lowercase) and the column name (all uppercase).

The following table columns are obsolete and should not be used.
Until the columns are removed, they will be maintained internally by 
DNA.pm and Processable.pm.

=cut

#App::DB->hide_table_columns(".+\._OLD");
#App::DB->hide_table_columns('.+_OLD$');
App::DB->hide_table_columns(qr/.+\._OLD$/);

%App::DB::tables_for_instance = (
    olap => {
        map { $_ => 1 } qw(
            READ_FACT
            PRODUCTION_READ_FACT
            SOURCE_SAMPLE_DIM
            SEQ_DIM
            PRODUCTION_MACHINE_DIM
            RUN_DIM
            PRODUCTION_EMPLOYEE_DIM
            PRODUCTION_DATE_DIM
            LIBRARY_CORE_DIM
            PROCESSING_DIM
            ARCHIVE_PROJECT_DIM
        )
    },
);




#####
#
# Tell App::DB how to resolve database logins.
#
#####

=pod

=item *

The database is configured by default to connect to the gsc schema,
using the "production" variant, with read-only access.  This can be
modified as needed in the app, or on the command-line.

=cut

# setup all logins
my @logins = (

    # OLTP production
    [qw(gscprod gsc GSC gscuser g_user rw production GSC)],
    [qw(gscprod gsc GSC devuser iamonrac rw-developer production GSC)],
    [qw(gscprod gsc GSC gscguest g_guest ro production GSC)],
    [qw(gscprod gsc GSC devguest dg_rac ro-developer production GSC)],

    # DW production
    [qw(dwrac gsc GSC gscuser user_dw rw production GSC)],
    [qw(dwrac gsc GSC devuser iamondw rw-developer production GSC)],
    [qw(dwrac gsc GSC gscguest guest_dw ro production GSC)],
    [qw(dwrac gsc GSC devguest dg_dw ro-developer production GSC)],

    # OLAP production
    [qw(ldb64 gsc GSCUSER gscuser user_64 rw production GSC)],
    [qw(ldb64 gsc GSCUSER gscguest guest64 ro production GSC)],

    # OLTP development
#    [qw(dbdev gsc GSC gscuser g_user rw development GSC)],
#    [qw(dbdev gsc GSC devuser iamonrac rw-developer development GSC)],
#    [qw(dbdev gsc GSC gscguest g_guest ro development GSC)],
#    [qw(dbdev gsc GSC devguest dg_rac ro-developer development GSC)],

#    # OLTP development
#    [qw(devdb gsc GSC gscuser dev_user rw development GSC)],
#    [qw(devdb gsc GSC devuser iamonracdev rw-developer development GSC)],
#    [qw(devdb gsc GSC gscguest dev_guest ro development GSC)],
#    [qw(devdb gsc GSC devguest dg_racdev ro-developer development GSC)],

    # OLTP old development
#    [qw(gscnew gsc GSC gscuser user_new rw old-development GSC)],
#    [qw(gscnew gsc GSC devuser iamonracnew rw-developer old-development GSC)],
#    [qw(gscnew gsc GSC gscguest guest_new ro old-development GSC)],
#    [qw(gscnew gsc GSC devguest dg_new ro-developer old-development GSC)],

    # DW development
    [qw(dwdev gsc GSC gscuser user_dev rw development GSC)],
    [qw(dwdev gsc GSC devuser iamondwdev rw-developer development GSC)],
    [qw(dwdev gsc GSC gscguest guest_dev ro development GSC)],
    [qw(dwdev gsc GSC devguest dg_dwdev ro-developer development GSC)],

    # tilepath
    [qw(gscprod tilepath SSMITH ssmith blue22 rw tilepath_production GSC)],
#    [qw(gscnew tilepath SSMITH ssmith blue22 rw tilepath_development GSC)],
    [qw(gscprod tilepath SSMITH ssmith blue22 ro tilepath_production GSC)],
#    [qw(gscnew tilepath SSMITH ssmith blue22 ro tilepath_development GSC)],
);

for my $login (@logins) {
    my %param;
    @param{qw(server schema owner login auth access cache_name entity_prefix)} = @$login;
    App::DB::Login->create_object(%param);
}

# setup all servers
my @servers = (

    # production servers
    [qw(gscprod  Oracle  oltp_prod)],
    [qw(dwrac    Oracle  dw_prod)],
    [qw(ldb64    Oracle  olap_prod)],

    # development servers
#    [qw(gscnew   Oracle  old_oltp_dev)],
#    [qw(dbdev    Oracle  oltp_dev)],
    [qw(dwdev    Oracle  dw_dev)],
);

for my $server (@servers) {
    my %param;
    @param{qw(server driver link)} = @$server;
    App::DB::Server->create_object(%param);
}

# setup all variants
my @variants = (

    # production variants
    [qw(production       oltp       gscprod)],
    [qw(production       warehouse  dwrac)],
    [qw(production       olap       ldb64)],

    # development variants
#    [qw(development      oltp       dbdev)],
    [qw(development      warehouse  dwdev)],

    # old development variants
#    [qw(old-development  oltp       gscnew)],
);

for my $variant (@variants) {
    my %param;
    @param{qw(variant instance server)} = @$variant;
    App::DB::Variant->create_object(%param);
}

# Set a default handle to use unless settings like this have
# been made already and inherited via environment variables.
# (We just check one of the values since if one is set, all
# were given at least a default value.)
for my $property_value (
    ['db_schema', 'gsc'],
    ['db_instance', 'oltp'],
    ['db_variant', 'production'],
    ['db_access_level', 'ro'],
)
{
    my ($property,$value) = @$property_value;
    unless (App::DB->$property) {
        App::DB->$property($value);
    }        
}    

# on unix verify gtkrc is set properly
if ($^O ne 'MSWin32') {
    my ($login, $real_name) = (getpwuid($<))[0, 6];

    # only do this for logins with /gscuser (e.g. do not run on touchscreen)
	if (-e "/gscuser/$login" && !-e "/gscuser/$login/.gtkrc") {


	    my $gtkrc = <<END_GTKRC;
# This script is auto-written by gsc-gtkrc
# and is customized for $real_name

# Do not edit this file! Instead, please add customizations to
# /gscuser/$login/.gtkrc.mine

style "user-font"
{
  fontset="-adobe-helvetica-medium-r-normal--*-80-*-*-*-*-*-*"
}
widget_class "*" style "user-font"

include "/gscuser/$login/.gtkrc.mine"

END_GTKRC

           open (OUT, ">/gscuser/$login/.gtkrc");
           print OUT $gtkrc;
           close (OUT);

        }



}

=pod

=back

=head1 METHODS

These methods provide the basic functionality common to (nearly) all
applications.

=over 4

=item disable_barcode_printing

  GSCApp->disable_barcode_printing(1);
  print_barcode() unless GSCApp->disable_barcode_printing;

This flag lets other modules know if they should actually print
barcodes.

=cut

# set or return barcode printing flag
our $disable_barcode_printing;
sub disable_barcode_printing
{
    my $class = shift;
    $disable_barcode_printing = $_[0] if (@_);    
    return $disable_barcode_printing;
}

=pod

=item number_to_alpha

  GSCApp->number_to_alpha(435);

Converts a number into an alphanumeric string, using a default formula
such that the number->letter correlation is 1:1 and consistant.

For example: 0->a, 1->b, 25->z, 26->aa, 27->ab, 28->ac, 701->zz,
702->aaa, 703->aab, and so on.

=cut

# convert number into alphanumeric string
sub number_to_alpha
{
    my $class = shift;
    
    # This is used to build alpha extensions for things like Clone_Growths
    # It calls itself recursively for multidigit return values.
    
    my $num = shift;
    my ($base, $remainder);
    
    $base = int($num/26);
    $remainder = $num % 26;
    
    my $base_string;
    if ($base > 0)
    {
        $base_string = number_to_alpha($base-1);
    }
    else
    {
        $base_string = '';
    }    
    return($base_string . chr(ord('a') + $remainder));
}

1;
__END__

=pod

=back

=head1 BUGS

Report bugs to <software@watson.wustl.edu>.

=head1 SEE ALSO

App(3), App::Object(3), App::DB(3), App::UI(3), App::Msgr(3),
App::Lock(3), App::Debug(3), App::ACL(3), App::Mail(3), App::Print(3),
App::MsgLogger(3), GSCApp::DBI(3), GSCApp::Mail(3),
GSCApp::Print::Barcode(3), GSCApp::QLock(3), GSC::Processable(3),

=head1 AUTHOR

Scott Smith <ssmith@watson.wustl.edu>

=cut

# $Id$
# $HeadURL$
