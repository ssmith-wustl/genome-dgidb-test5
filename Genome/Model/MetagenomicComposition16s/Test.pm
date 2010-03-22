##############
# Mock Model #
##############

package Genome::Model::MetagenomicComposition16s::Test;

use strict;
use warnings;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub create_mock_mc16s_model {
    my ($self, %params) = @_;

    my $sequencing_platform = delete $params{sequencing_platform}
        or confess "No sequencing platform to create mock metagenomic composition 16s model";
    my $use_mock_dir = delete $params{use_mock_dir};

    my $model = Genome::Model::Test->create_basic_mock_model(
        type_name => 'metagenomic composition 16s '.$sequencing_platform,
        use_mock_dir => $use_mock_dir,
    ) or confess "Can't create mock mc16s model";

    my $inst_data_method = '_create_mock_'.$sequencing_platform.'_instrument_data';
    my $inst_data = $self->$inst_data_method
        or die "Can't create mock instrument data for mc16s model";
    Genome::Model::Test->create_mock_instrument_data_assignments($model, $inst_data)
        or die "Can't assign $sequencing_platform instrument data to mc16s model";
    
    return $model;
}

sub create_mock_build_for_mc16s_model {
    my ($self, $model) = @_;

    confess "No mc116s model given to create mock build" unless $model;
    
    my $build = Genome::Model::Test->add_mock_build_to_model($model)
        or confess "Can't add mock build to model";

    return $build;
}

sub _instrument_data_dir {
    return '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16s'.
    ucfirst($_[1]).'/inst_data';
}

sub _create_mock_sanger_instrument_data {
    my $self = shift;

    my $run_name = '01jan00.101amaa';
    my $full_path = $self->_instrument_data_dir('sanger').'/'.$run_name;
    confess "Mock instrument data directory ($full_path) does not exist" unless -d $full_path;
    my $inst_data = Genome::Model::Test->create_mock_object(
        class => 'Genome::InstrumentData::Sanger',
        id => $run_name,
        run_name => $run_name,
        sequencing_platform => 'sanger',
        seq_id => $run_name,
        sample_name => 'unknown',
        subset_name => 1,
        library_name => 'unknown',
        full_path => $full_path,
    ) or die "Can't create mock sanger instrument data";
    $inst_data->mock('resolve_full_path', sub{ return $full_path; });
    $inst_data->mock('dump_to_file_system', sub{ return 1; });

    return $inst_data;
}

sub _create_mock_454_instrument_data {
    my $self = shift;

    my $id = 2848985861;
    my $full_path = $self->_instrument_data_dir('454').'/'.$id;
    confess "Mock instrument data directory ($full_path) does not exist" unless -d $full_path;
    my $inst_data = Genome::Model::Test->create_mock_object (
        class => 'Genome::InstrumentData::454',
        id => $id,
        seq_id => $id,
        region_id => $id,
        analysis_name => 'D_2010_01_10_04_22_16_blade9-2-5_fullProcessing',
        region_number => 2,
        total_raw_wells => 1176187,
        total_key_pass => 1169840,
        incoming_dna_name => 'Pooled_Library-2009-12-31_1-1',
        copies_per_bead => 2.5,
        run_name => 'R_2010_01_09_11_08_12_FLX08080418_Administrator_100737113',
        key_pass_wells => 1170328,
        predicted_recovery_beads => 371174080,
        fc_id => undef,
        sample_set => 'Tarr NEC 16S Metagenomic Sequencing master set',
        research_project => 'Tarr NEC 16S Metagenomic Sequencing',
        paired_end => 0,
        sample_name => 'H_MA-.0036.01-89503877',
        library_name => 'Pooled_Library-2009-12-31_1',
        beads_loaded => 1999596,
        ss_id => undef,
        supernatant_beads => 254520,
        sample_id => 2847037746,
        library_id => 2848636935,
        #library_name => 'Pooled_DNA-2009-03-09_23-lib1',
        sequencing_platform => '454',
        full_path => $full_path,
    ) or confess "Unable to create mock 454 id #";
    $inst_data->mock('fasta_file', sub {  #FIXME
            return $full_path.'/Titanium17_2009_05_05_set0.fna';
        }
    );
    #$id->mock('log_file', sub {return 'mock_test_log';});
    #my $barcode_file = $dir .'454_Sequencing_log_Titanium_test.txt';
    #$id->mock('barcode_file', sub {return $barcode_file;});
    $inst_data->mock('dump_to_file_system', sub{ return 1; });

    return $inst_data;
}

####################################
# Test Base for Events and Reports #
####################################

package Genome::Model::MetagenomicComposition16s::TestCommandBase;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use File::Basename 'basename';
use Test::More;

#< Startup ># 
sub startup : Tests(startup => no_plan) {
    my $self = shift; 

    $self->_ur_no_commit_and_dummy_ids
        or return;
    
    my %classes_and_methods_to_overload = $self->_classes_and_methods_to_overload;
    for my $class ( keys %classes_and_methods_to_overload ) {
        for my $method ( @{$classes_and_methods_to_overload{$class}} ) {
            no strict 'refs';
            no warnings;
            *{$class.'::'.$method} = sub{ return 1; };
        }
    }

    if ( $self->_dirs_to_link and $self->_use_mock_dir ) {
        die "Can't link dirs and use a existing mock build";
    }
    
    for my $dir ( $self->_dirs_to_link ) {
        $self->_link_contents_of_dir($dir);
    }

    return 1;
}

sub _classes_and_methods_to_overload { 
    return; # none ok
}

sub _dirs_to_link {
    return;
}

sub _link_contents_of_dir {
    my ($self, $dir_to_link) = @_;

    my $dest_dir = $self->_build->$dir_to_link;
    Genome::Utility::FileSystem->validate_existing_directory($dest_dir)
        or confess;

    my $dir_base_name = File::Basename::basename($dest_dir);
    my $source_dir = '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16s'.ucfirst($self->_sequencing_platform).'/build/'.$dir_base_name;
    my $dh = Genome::Utility::FileSystem->open_directory($source_dir)
        or confess;

    $dh->read; $dh->read; # . and .. dirs
    while ( my $file = $dh->read ) {
        my $target = "$source_dir/$file";
        my $link =  $dest_dir.'/'.$file;
        unless ( symlink($target, $link) ) {
            confess "Can't symlink ($target) to ($link): $!.";
        }
    }

    return 1;
}

#< Params >#
sub valid_param_sets {
    return {
        before_execute => 'before_execute',
        after_execute => 'after_execute',
        build_id => $_[0]->_build->id,
    } 
}
sub before_execute { return 1; }
sub after_execute { return 1; }

sub required_property_names {
    return (qw/ build_id /);
}

#< Model/Build >#
sub _sequencing_platform {
    return 'sanger';
}

sub _use_mock_dir {
    return 0;
}

sub _model {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::MetagenomicComposition16s::Test->create_mock_mc16s_model(
            sequencing_platform => $self->_sequencing_platform,
            use_mock_dir => $self->_use_mock_dir,
        );
    }

    return $self->{_model};
}

sub _build {
    my $self = shift;

    unless ( $self->{_build} ) {
        $self->{_build} = Genome::Model::MetagenomicComposition16s::Test->create_mock_build_for_mc16s_model(
            $self->_model,
        );
    }

    return $self->{_build};
}

sub _amplicons {
    my $self = shift;

    unless ( $self->{_amplicons} ) {
        $self->{_amplicons} = [];
        my $amplicon_set = $self->_build->amplicon_sets
            or die "No amplicons found";
        while ( my $amplicon = $amplicon_set->() ) {
            push @{$self->{_amplicons}}, $amplicon;
        }
    }

    return $self->{_amplicons};
}

##############
# Base Event #
##############

package Genome::Model::Event::Build::MetagenomicComposition16s::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;

use Test::More;

# Since the test class is abstract, make a class to inherit from it, and use that for testing
class Genome::Model::Event::Build::MetagenomicComposition16s::Tester {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s',
};

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Tester';
}

sub test01 : Tests() {
    my $self = shift;

    is($self->test_class->bsub_rusage, "-R 'span[hosts=1]'", 'Busb rusage');

    return 1;
}

#########################
# PrepareInstrumentData #
#########################

package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;

# Since the test class is abstract, make a class to inherit from it, and use that for testing
class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Tester {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData',
};

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Tester';
}

######

package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use File::Compare 'compare';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger';
}

sub after_execute {
    my $self = shift;

    my $build = $self->_build;
    my $amplicons = $self->_amplicons;
    for my $amplicon ( @$amplicons ){
        ok(-s $build->scfs_file_for_amplicon($amplicon), 'scfs file');
        ok(-s $build->phds_file_for_amplicon($amplicon), 'phds file');
        ok(-s $build->reads_fasta_file_for_amplicon($amplicon), 'fasta file');
        ok(-s $build->reads_qual_file_for_amplicon($amplicon), 'qual file');
    }
    ok(-s $build->raw_reads_fasta_file, 'Created the raw reads fasta file');
    ok(-s $build->raw_reads_qual_file, 'Created the raw reads qual file');
    #print $build->data_directory."\n";<STDIN>;
    
    return 1;
}

######

package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454';
}

sub _sequencing_platform {
    return '454';
}

########
# Trim #
########

package Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;

# Since the test class is abstract, make a class to inherit from it, and use that for testing
class Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Tester {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::Trim',
};

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Tester';
}

######

package Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Finishing::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;

use File::Compare 'compare';

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Finishing';
}

sub _dirs_to_link { return (qw/ chromat_dir edit_dir /); }

sub after_execute {
    my $self = shift;

    my $build = $self->_build;
    ok(-s $build->processed_reads_fasta_file, 'Created the processed reads fasta file');
    ok(-s $build->processed_reads_qual_file, 'Created the processed reads qual file');
    #print $build->data_directory."\n";<STDIN>;

    return 1;
}

############
# Assemble #
############

package Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;

# Since the test class is abstract, make a class to inherit from it, and use that for testing
class Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::Tester {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::Assemble',
};

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::Tester';
}

######

package Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::PhredPhrap::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::PhredPhrap';
}

sub _dirs_to_link { return (qw/ chromat_dir edit_dir /); }

sub before_execute {
    my $self = shift;

    my $build = $self->_build;
    my $amplicons = $self->_amplicons
        or return;
    for my $amplicon ( @$amplicons ) {
        my $ace_file = $build->ace_file_for_amplicon($amplicon);
        unlink $ace_file 
            or die "Could not remove ace file: $ace_file\n";
    }

    return 1;
}

sub after_execute {
    my $self = shift;

    my $build = $self->_build;
    my $amplicons = $self->_amplicons
        or return;
    for my $amplicon ( @$amplicons ){
        ok(-s $build->ace_file_for_amplicon($amplicon), 'ace file');
    }
    ok(-s $build->processed_fasta_file, 'Created the processed fasta file');
    ok(-s $build->processed_qual_file, 'Created the processed qual file');
    #print $build->data_directory."\n";<STDIN>;
    
    return 1;
}

############
# Classify #
############

package Genome::Model::Event::Build::MetagenomicComposition16s::Classify::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;

require File::Copy;
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Classify';
}

sub _dirs_to_link { return (qw/ chromat_dir edit_dir /); }

sub before_execute {
    my $self = shift;

    my $build = $self->_build;
    $build->amplicons_processed(0);
    is($build->amplicons_processed, 0, 'amplicons processed reset');
    $build->amplicons_processed_success(0);
    is($build->amplicons_processed_success, 0, 'amplicons processed success reset');
    
    $build->amplicons_classified(0);
    is($build->amplicons_classified, 0, 'amplicons classified reset');
    $build->amplicons_classified_success(0);
    is($build->amplicons_classified_success, 0, 'amplicons classified success reset');

    return 1;
}

sub after_execute {
    my $self = shift;

    my $build = $self->_build;
    my $amplicons  = $self->_amplicons;
    my $cnt = grep { -s $build->classification_file_for_amplicon($_) } @$amplicons;
    is($cnt, 4, 'Verified - Created classification for 4 of 5 amplicons');

    is($build->amplicons_processed, 4, 'amplicons processed recorded');
    is($build->amplicons_classified, 4, 'amplicons classified recorded');
    
    ok(-s $build->classification_file, 'build classification file');
    
    #print $build->data_directory."\n";<STDIN>;
    
    return 1;
}

###########
# Reports #
###########

package Genome::Model::Event::Build::MetagenomicComposition16s::Reports::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Reports';
}

sub _dirs_to_link { return (qw/ chromat_dir edit_dir classification_dir /); }

sub after_execute {
    my $self = shift;

    my @reports = glob($self->_build->reports_directory.'/*');
    is(@reports, 2, "Created 2 reports");

    return 1;
}

##########
# Orient #
##########

package Genome::Model::Event::Build::MetagenomicComposition16s::Orient::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::Orient';
}

sub _dirs_to_link { return (qw/ chromat_dir edit_dir classification_dir /); }

sub after_execute {
    my $self = shift;

    my $build = $self->_build;
    ok(-s $build->oriented_fasta_file, 'oriented fasta file was created');
    ok(-s $build->oriented_qual_file, 'oriented qual file was created');
    #print $build->data_directory."\n";<STDIN>;

    return 1;
}

############
# Clean Up #
############

package Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Genome;
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp';
}

sub _dirs_to_link { return (qw/ chromat_dir edit_dir /); }

sub before_execute {
    my $self = shift;

    my @files_remaining = glob($self->_build->edit_dir.'/*');
    is(@files_remaining, 80, "Start w/ correct number of files");

    return 1;
}

sub after_execute {
    my $self = shift;

    my @files_remaining = glob($self->_build->edit_dir.'/*');
    is(@files_remaining, 80, "Removed correct number of files");
    #is(@files_remaining, 15, "Removed correct number of files");
    #print $self->_build->data_directory."\n";<STDIN>;

    return 1;
}

###########
# Reports #
###########

package Genome::Model::MetagenomicComposition16s::Report::TestBase;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::TestCommandBase';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub method_for_execution {
    return 'generate_report';
};

sub _use_mock_dir { # use a real build to generate and compare report
    return 1;
}

sub after_execute {
    my ($self, $summary, $params, $report) = @_;

    #$report->save($self->_build->reports_directory, 1);
    my $existing_report = Genome::Report->create_report_from_directory(
        $self->_build->reports_directory.'/'.$report->name_to_subdirectory($report->name)
    );
    ok($existing_report, 'existing report');

    my @datasets = $report->get_datasets;
    my @existing_datasets = $existing_report->get_datasets;
    for ( my $i = 0; $i < @datasets; $i++ ) {
        is($datasets[$i]->to_xml_string, $existing_datasets[$i]->to_xml_string, $datasets[$i]->name);
    }

    return $self->_verify($summary, $params, $report);
}

sub _verify {
    return 1;
}

######

package Genome::Model::MetagenomicComposition16s::Report::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

# Since the test class is abstract, make a class to inherit from it, and use that for testing
class Genome::Model::MetagenomicComposition16s::Report::Tester {
    is => 'Genome::Model::MetagenomicComposition16s::Report',
    has => [
    description => { default_value => 'DESC', },
    ],
};
sub Genome::Model::MetagenomicComposition16s::Report::Tester::_add_to_report_xml {
    return 1;
}

sub test_class {
    return 'Genome::Model::MetagenomicComposition16s::Report::Tester';
}

sub after_execute {
    return 1;
}

######

package Genome::Model::MetagenomicComposition16s::Report::Summary::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::Report::TestBase';

use Data::Dumper 'Dumper';
require File::Temp;
require File::Compare;
use Test::More;

sub test_class {
    'Genome::Model::MetagenomicComposition16s::Report::Summary';
}

######

package Genome::Model::MetagenomicComposition16s::Report::Composition::Test;

use strict;
use warnings;

use base 'Genome::Model::MetagenomicComposition16s::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::Model::MetagenomicComposition16s::Report::Composition';
}

######
######
######

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2010 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@genome.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/MetagenomicComposition16s/Test.pm $
#$Id: Test.pm 54265 2010-01-05 16:50:07Z ebelter $

