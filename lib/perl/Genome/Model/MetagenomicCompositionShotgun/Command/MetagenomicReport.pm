package Genome::Model::MetagenomicCompositionShotgun::Command::MetagenomicReport;

use strict;
use warnings;
use Genome;
use Genome::Model::InstrumentDataAssignment;
use File::Path;
use File::Find;

$|=1;

class Genome::Model::MetagenomicCompositionShotgun::Command::MetagenomicReport{
    is => 'Genome::Command::OO',
    doc => 'Generate reports for a MetagenomicCompositionShotgun build.',
    has => [
        model => {
            is => 'Genome::Model::Build::MetagenomicCompositionShotgun', # we're going to remove "Imported" soon
            is_optional => 1,
        },
        model_id => {
            is => 'Int',
            is_optional => 1,
        },
        model_name => {
            is => 'Text',
            is_optional => 1,
        },
        overwrite => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
        },
        report_path => {
            is => 'Text',
            is_optional => 1,
        },
		log_path => {
			is => 'Text',
			is_optional => 1,
		},
        base_output_dir => {
            is => 'Text',
            is_optional => 1,
            default => '/gscmnt/sata835/info/medseq/hmp-july2010',
        },
        taxonomy_file => {
            is => 'Parh',
            is_optional => 1,
            default => '/gscmnt/sata409/research/mmitreva/databases/Bact_Arch_Euky.taxonomy.txt',
        },
        viral_taxonomy_file => {
            is => 'Path',
            is_optional => 1,
            default => '/gscmnt/sata409/research/mmitreva/databases/viruses_taxonomy_feb_25_2010.txt',
        },
    ],
};


sub execute {
    my ($self) = @_;
    my $model;
    if ($self->model_id and $self->model_name){
        die 'error';
    }elsif ($self->model_id){
        $model = Genome::Model->get($self->model_id);
        die 'no model' unless $model;
        $self->model($model);
    }elsif ($self->model_name){
        $model = Genome::Model->get(name => $self->model_id);
        die 'no model' unless $model;
        $self->model($model);
    }else{
        die 'provide model id or name';
    };

    my $build = $model->last_succeeded_build;
    die 'no build' unless $build;

    unless ($self->report_path){
        my $sample_name = $model->subject_name;
        my ($hmp, $patient, $site) = split(/-/, $sample_name);
        $patient = $hmp . '-' . $patient;
        my $build_id = $build->id;
        my $output_dir = $self->base_output_dir . "/" . $patient . "/" . $site . "/" . $build_id."/metagenomic";
        mkpath $output_dir unless -d $output_dir;
        # TODO: check and warn if dir for different successful build id is present
        $self->report_path($output_dir);
    }
    unless ($self->log_path){
        $self->log_path($self->report_path . '/log');
    }
    $self->log("Report path: " . $self->report_path);


    my $dir = $build->data_directory;
    my ($meta1_bam, $meta1_flagstat, $meta2_bam, $meta2_flagstat) = map{ $dir ."/$_"}(
        "metagenomic_alignment1.bam",
        "metagenomic_alignment1.bam.flagstat",
        "metagenomic_alignment2.bam",
        "metagenomic_alignment2.bam.flagstat",
    );

    my $merged_bam = $self->report_path."/merged_metagenomic_alignment.bam";
    if (-e $merged_bam and -e $merged_bam.".OK"){
        $self->log("metagenomic merged bam already produced, skipping");
    }else{
        my $rv;

        $self->log("starting sort and merge");

        eval{
            $rv = Genome::Model::Tools::Sam::SortAndMergeSplitReferenceAlignments->execute(
                input_files => [$meta1_bam, $meta2_bam],
                input_format=> "BAM",
                output_file => $merged_bam,
                output_format => "BAM",
            );
        };
        if ($@ or !$rv){
            $self->error_message("Failed to sort and merge metagenomic bams: $@");
            die;
        }

        unless (-s $merged_bam){
            $self->error_message("Merged bam has no size!");
            die;
        }

        system ("touch $merged_bam.OK");
    }

    $self->log("Finished sort and merge, compiling metagenomic reports");


    $self->log("Starting taxonomy count...\n");
    $DB::single = 1;

    # Load Taxonomy From Taxonomy Files
    my $taxonomy;
    my %taxon_map = (
        species => '1',
        phyla   => '2',
        genus   => '3',
        order   => '4',
        hmp     => '5',
    );
    $taxonomy = $self->_load_taxonomy($self->taxonomy_file, 'Species', \%taxon_map);
    unless(%$taxonomy) {
        $self->error_message("No taxonomy data loaded from " . $self->taxonomy_file . "!");
        die $self->error_message;
    }

    my $viral_taxonomy;
    my %viral_taxon_map = (
        species    => '1',
        genus      => '2',
        subfamily  => '3',
        family     => '4',
        infraorder => '5',
        suborder   => '6',
        superorder => '7',
    );
    $viral_taxonomy = $self->_load_taxonomy($self->viral_taxonomy_file, 'gi', \%viral_taxon_map);
    unless(%$viral_taxonomy) {
        $self->error_message("No viral taxonomy data loaded from " . $self->viral_taxonomy_file . "!");
        die $self->error_message;
    }

    $DB::single = 1;

    # Count Reference Hits
    my %ref_counts_hash;
    my $ignore_unmapped;
    my $ignore_singleton;
    my $fh = IO::File->new("samtools view $merged_bam |");
    while (<$fh>){
        my @fields = split(/\t/, $_);
        my $bitflag = $fields[1];
        if ($bitflag & 0x0004){
            $ignore_unmapped++;
            next;
        }
        if ($bitflag & 0x0001){
            $ignore_singleton++;
            next;
        }
        my ($ref_name, $null, $gi) = split(/\|/, $fields[2]);
        if ($ref_name eq "VIRL"){
            $ref_name .= "_$gi";
        }
        $ref_counts_hash{$ref_name}++;
    }
    
    $self->log("skipping $ignore_unmapped reads without a metagenomic mapping");
    $self->log("skipping $ignore_singleton fragment reads(mate mapped to human)");

    # Count And Record Taxonomy Hits
    my $read_count_output_file = $self->report_path . '/read_count_output';
    unlink $read_count_output_file if -e $read_count_output_file;
    my $read_cnt_o = Genome::Utility::FileSystem->open_file_for_writing($read_count_output_file);

    my %species_counts_hash;
    my %phyla_counts_hash;
    my %genus_counts_hash;
    my %viral_family_counts_hash;
    my %viral_subfamily_counts_hash;
    my %viral_genus_counts_hash;
    my %viral_species_counts_hash;


    $self->log('creating metagenomic count files');

    print $read_cnt_o "Reference Name\t#Reads with hits\tSpecies\tPhyla\tHMP genome\n";
    do {
        use warnings FATAL => 'all';
        for my $ref_id (sort keys %ref_counts_hash){
            if (($ref_id =~ /^BACT/) or ($ref_id =~ /^ARCH/) or ($ref_id =~ /^EUKY/)){
                my $species= $taxonomy->{$ref_id}->{species} || '';
                $species_counts_hash{$species}+=$ref_counts_hash{$ref_id};
                my $phyla=$taxonomy->{$ref_id}->{phyla} || '';
                $phyla_counts_hash{$phyla}+=$ref_counts_hash{$ref_id};
                my $genus=$taxonomy->{$ref_id}->{genus} || '';
                $genus_counts_hash{$genus}+=$ref_counts_hash{$ref_id};
                my $hmp_flag=$taxonomy->{$ref_id}->{hmp}|| '';	
                print $read_cnt_o "$ref_id\t$ref_counts_hash{$ref_id}\t$species\t$phyla\t$hmp_flag\n";
            }elsif ($ref_id =~ /^VIRL/){ #produce reports for viral taxonomy if available
                my ($gi) = $ref_id =~/^VIRL_(\d+)$/;
                if ($viral_taxonomy->{$gi}){
                    my $species = $viral_taxonomy->{$gi}->{species} || '';
                    $viral_species_counts_hash{$species}+=$ref_counts_hash{$ref_id};
                    my $genus = $viral_taxonomy->{$gi}->{genus} || '';
                    $viral_genus_counts_hash{$genus}+=$ref_counts_hash{$ref_id};
                    my $family = $viral_taxonomy->{$gi}->{family} || '';
                    $viral_family_counts_hash{$family}+=$ref_counts_hash{$ref_id};
                    my $subfamily = $viral_taxonomy->{$gi}->{subfamily} || '';
                    $viral_subfamily_counts_hash{$subfamily}+=$ref_counts_hash{$ref_id};
                    print $read_cnt_o "$ref_id\t$ref_counts_hash{$ref_id}\t$species\t\t\n";
                }else{
                    print $read_cnt_o "$ref_id\t$ref_counts_hash{$ref_id}\t\t\t\n";
                }
            }else{
                print $read_cnt_o "$ref_id\t$ref_counts_hash{$ref_id}\t\t\t\n";
            }
        }
    };
    $read_cnt_o->close;

    my $species_output_file = $self->report_path . '/species_count';
    my $phyla_output_file = $self->report_path . '/phyla_count';
    my $genus_output_file = $self->report_path . '/genus_count';
    my $viral_family_output_file = $self->report_path . '/viral_family_count';
    my $viral_subfamily_output_file = $self->report_path . '/viral_subfamily_count';
    my $viral_genus_output_file = $self->report_path . '/viral_genus_count';
    my $viral_species_output_file = $self->report_path . '/viral_species_count';
    $self->_write_count_and_close($species_output_file, "Species", \%species_counts_hash);
    $self->_write_count_and_close($phyla_output_file, "Phyla", \%phyla_counts_hash);
    $self->_write_count_and_close($genus_output_file, "Genus", \%genus_counts_hash);
    $self->_write_count_and_close($viral_species_output_file, "Viral Species", \%viral_species_counts_hash);
    $self->_write_count_and_close($viral_genus_output_file, "Viral Genus", \%viral_genus_counts_hash);
    $self->_write_count_and_close($viral_family_output_file, "Viral Family", \%viral_family_counts_hash);
    $self->_write_count_and_close($viral_subfamily_output_file, "Viral Subfamily", \%viral_subfamily_counts_hash);

    system("touch ".$self->report_path."/FINISHED");
    $self->log("metagenomic report successfully completed");
    return 1;
}

sub log {
    my $self = shift;
    my $str = shift;
    my @time_data = localtime(time);

    $time_data[1] = '0' . $time_data[1] if (length($time_data[1]) == 1);
    $time_data[2] = '0' . $time_data[2] if (length($time_data[2]) == 1);

    my $time = join(":", @time_data[2, 1]);

    print $time . " - $str\n";
    my $log_fh = IO::File->new('>>' . $self->log_path);
    print $log_fh $time . " - $str\n";
}

sub _load_taxonomy {
    my ($self, $filename, $header_ignore_str, $taxon_map_ref) = @_;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($filename);
    my $taxonomy = {};
    my $header = <$fh>;
    unless ($header =~ /^$header_ignore_str/) {
        die "unexpected header $header!  expected =~ $header_ignore_str";
    }
    while (<$fh>) {
        chomp;
        if (/^$header_ignore_str/) {
            die "duplicated header?!?!: $_\n";
        }
        my @fields = split(/\t/, $_);
        for (@fields) {
            s/^\s+//; 
            s/\s+$//;
        }
        # todo: this is a one-line hash slice -ss
        my $ref_id = $fields[0]; 
        for my $taxon (keys %$taxon_map_ref) {
            $taxonomy->{$ref_id}{$taxon} = $fields[$taxon_map_ref->{$taxon}];
        }
    }
    return $taxonomy;
}

sub _write_count_and_close {
    my($self, $filename, $title, $counts_ref) = @_;
    unlink $filename if -e $filename;
    my $file_o=Genome::Utility::FileSystem->open_file_for_writing($filename);
    print $file_o "$title Name\t#Reads with hits\n";
    for my $name (keys %$counts_ref){
        next if (($name eq "") or ($name =~ /^\s+$/));
        print $file_o "$name\t$counts_ref->{$name}\n";
    }
    $file_o->close;
}



1;
