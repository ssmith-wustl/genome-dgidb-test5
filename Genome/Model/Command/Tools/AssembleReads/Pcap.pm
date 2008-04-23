
package Genome::Model::Command::Tools::AssembleReads::Pcap;

use strict;
use warnings;

use above "Genome";  
use IO::File;                       

class Genome::Model::Command::Tools::AssembleReads::Pcap {
    is => 'Command',                       
    has => [  
	      project_name     => { 
		                   type => 'String',
				   doc => "project name"
			          },
	      data_path        => {
		                   type => 'String',
				   is_optional => 1,
				   is_transient => 1,
				   doc => "path to the data"
				  },
              pcap_run_type    => {  
		                   type => 'String',
				   is_optional => 1,
				   doc => "pcap type to run eg with_454"
				  },
              dna_prefix       => {
		                   type => 'String',
				   is_optional => 1,
				   doc => "dna prefix use to find reads"
			          },
	      assembly_version => {
		                   type => 'String',
       				   is_optional => 1,
				   doc => "assembly version number",
	                          }, 
	      config_file      => {
		                   type => 'String',
                                   doc => "configeration file",
                                   is_optional => 1,
	                          },
	   ], 
};



sub help_brief {
    "launch pcap assembler"		    
}

sub help_synopsis {                         
    return <<EOS
genome-model tools assemble-reads pcap --project_name EA_ASSEMBLY
EOS
}

sub help_detail {                           
    return <<EOS 
This launches pcap assembler
EOS
}


sub validate_params {
    my $self = shift;
    return unless $self->SUPER::validate_params(@_);
    # ..do real checks here
    return 1;
}

sub execute {
    my ($self) = @_;
    $self->status_message("assembling project " . $self->project_name);

    #check for input
    $self->load_config_file if $self->config_file;

    $self->error_message("assembly-version undefined") unless (defined $self->assembly_version);
    $self->error_message("data-path undefined") unless (defined $self->data_path);
    $self->error_message("project-name undefined") unless (defined $self->project_name);
    #TAKING NEXT TWO METHODS OUT UNTIL WE START TESTING ON FULL DATA SET

    unless ($self->data_path or $self->resolve_path_for_data)
    {
        $self->error_message("failed to resolve a path for the data!: " . $self->error_message);
        return;
    }
    $self->status_message("using directory " . $self->data_path);

    unless ($self->create_project_directories)
    {
        $self->error_message("failed to create project directories: " . $self->error_message);
        return;
    }

    #RUN PCAP

    unless ($self->create_pcap_input_fasta_fof)
    {
	$self->error_message("failed to create input fasta fof file") and return;
    }
    $self->status_message("creating input fasta file");

    unless ($self->create_constraint_file)
    {
	$self->error_message("failed to create constraint file") and return;
    }
    $self->status_message("creating constraint file");

    unless ($self->run_pcap)
    {
	$self->error_message("failed to run pcap.rep") and return;
    }
    $self->status_message("running pcap.rep");

    unless ($self->run_bdocs)
    {
	$self->error_message("failed to run bodcs") and return;
    }
    $self->status_message("running bdocs");

    unless ($self->run_bclean)
    {
	$self->error_message("failed to run bclean") and return;
    }
    $self->status_message("running bclean");

    unless ($self->run_bcontig)
    {
	$self->error_message("failed to run bclean") and return;
    }
    $self->status_message("running bclean");

    unless ($self->run_bconsen)
    {
	$self->error_message("failed to run bconsen") and return;
    }
    $self->status_message("running bconsen");

    unless ($self->run_bform)
    {
	$self->error_message("failed to run bform") and return;
    }
    $self->status_message("running bform");

    #CREATE POST PCAP FILES

    unless ($self->create_gap_file)
    {
	$self->error_message("failed to create gap file") and return;
    }
    $self->status_message("creating gap file");

    unless ($self->create_agp_file)
    {
	$self->error_message("failed to create agp file") and return;
    }
    $self->status_message("creating agp file");

    unless ($self->create_sctg_fa_file)
    {
	$self->error_message("failed to create supercontigs fasta file") and return;
    }
    $self->status_message("creating supercontigs fasta file");

    #CREATE STATS

    unless ($self->create_stats_file)
    {
	$self->error_message("failed to create stats files") and return;
    }
    $self->status_message("creating stats files");

    sleep 60;#give stats file jobs time to complete

    unless ($self->run_stats)
    {
	$self->error_message("failed to run stats") and return;
    }
    $self->status_message("creating stats");

    return 1;
}

sub resolve_path_for_data {
    my ($self) = @_;

    die "this method did not declare \$dir, and I wasn't sure what it intended to do.  I've disabled it because a module which doesn't complie breaks the build."
    
    #chomp (my $date = `date +%y%m%d`);
    #
    #my $project_root_name = $self->project_name.'-'.$self->assembly_version.'_'.$date;
    #
    #my $data_path = $dir.'/'.$project_root_name.'.pcap';
    #my $data_path = $self->data_path
    #return;
}

sub create_project_directories
{
    my ($self) = @_;
    my $path = $self->data_path;
    umask 002;
    mkdir "$path";
    unless (-d "$path")
    {
        $self->error_message ("failed to create $path : $!");
        return;
    }
    foreach my $sub_dir (qw/ edit_dir input output phd_dir chromat_dir blastdb acefiles ftp read_dump/) {
        mkdir "$path/$sub_dir";
        unless (-d "$path/$sub_dir")
        {
            $self->error_message ("failed to create $path/$sub_dir : $!");
            return;
        }
    }
    return 1;
}

sub dump_reads {
    my ($self) = @_;
    my $date = `date +%y%m%d`;
    chomp $date;
    my $dir = $self->data_path;
    my $read_dump_dir = $dir.'/read_dump';
    my $re_id_file_name = $date.'.re_id';
    my $re_id_file = $read_dump_dir.'/'.$re_id_file_name;
    my $dna_prefix = $self->dna_prefix;
    my $project_name = $self->project_name;

    if(defined $dna_prefix)
    {
        system ("sqlrun \"select re_id from sequence_read sr join funding_category f on ".
            "f.fc_id = sr.fc_id where f.dna_resource_prefix = \'$dna_prefix\' and ".
            "sr.pass_fail_tag = \'PASS\'\" --instance=warehouse --parse > $re_id_file");
    }
    else
    {
        system ("sqlrun \"select re_id from sequence_read where center_project = \'$project_name\' and ".
            "pass_fail_tag = \'PASS\'\" --instance=warehouse --parse > $re_id_file");
    }


    $self->error_message ("failed to create re_id file") and return unless -s $re_id_file;

    #do two separate queries for fasta and qual and phd and scf files
    #since not all assemblies will require dumping phd and scf files

    my $ec = system ("seq_dump --input-file $re_id_file --output type=qual,file=$dir\/edit_dir\/$re_id_file_name.fasta.qual ".
        "--output type=fasta,file=$dir\/edit_dir/$re_id_file_name.fasta,maskq=0,maskv=1,nocvl=35 ");

    $self->error_message ("seq_dump failed for fasta dump\n") and return unless -s "$dir\/edit_dir\/$re_id_file_name".'.fasta';
    $self->error_message ("seq_dump failed for qual dump\n") and return unless -s "$dir\/edit_dir\/$re_id_file_name".'.fasta.qual';

    $ec = system ("seq_dump --input-file $re_id_file --output type=phd,dir=$dir\/phd_dir --output type=scf,dir=$dir\/chromat_dir");

    $self->error_message ("seq_dump failed for phd and scf\n") and return if $ec;

    #fasta and qual files must be zipped
    #typically there would be multiple files for each fasta and qual
    my @fastas = glob ("$dir/edit_dir/*fasta");
    my @quals = glob ("$dir/edit_dir/*qual");

    foreach my $file (@fastas){
        $ec = system ("gzip $file");
        $self->error_message ("gzip failed for $file\n") and return if $ec;
    }

    @quals = glob ("$dir/edit_dir/*qual");
    foreach my $file (@quals) {
        $ec = system ("gzip $file");
        $self->error_message ("gzip failed for $file\n") and return if $ec;
    }

    #TODO: need to have separate controls for the two system calls above
    #TODO: find a good way to error check this since multiple phd/scf files dumped

    return 1;
}
sub create_pcap_input_fasta_fof {
    my ($self) = @_;
    my $dir = $self->data_path;
    my $input_fof = $self->project_name;

    my $fh = IO::File->new(">$dir/edit_dir/$input_fof");
    $self->error_message ("Unable to create pcap input file\n") and return unless $fh;
    my @fastas = glob ("$dir/edit_dir/*fasta.gz");
	 
	$self->error_message("Could not find any fasta files") and return if(!scalar @fastas);
    $self->error_message ("") and return unless scalar @fastas > 0;
    foreach my $file (@fastas)
    {
        my ($file_name) = $file =~ /edit_dir\/(\S+\.fasta)\.gz$/;
        $fh->print ("$file_name\n");
    }
    $fh->close;
    return 1;
}

sub create_constraint_file {
    my ($self) = @_;
    my $dir = $self->data_path;
    my $con_file = $self->project_name.'.con';
    my $con_fh = IO::File->new(">$dir/edit_dir/$con_file");

    my @fastas = glob ("$dir/edit_dir/*fasta.gz");
    my @inserts;
    foreach my $file (@fastas)
    {
        my $fh = IO::File->new ("zcat $file |");
        $self->error_message ("Unable to read $file\n") and return unless $fh;
        while(my $line = <$fh>)
        {
            next unless ($line =~ /^>/);
            my ($read_name) = $line =~ /^>(\S+)\s+/;
            my ($insert_size) = $line =~ /INSERT_SIZE:\s+(\d+)/;
            my ($root_name, $extension) = $read_name =~ /^(\S+)\.[bg](\d+)$/;
            next unless (defined $insert_size && defined $read_name && defined $root_name);

            my $fwd_read = $root_name.'.b'.$extension;
            my $rev_read = $root_name.'.g'.$extension;

            #lines should look like this
            #S_BA-aaa13c07.b1 S_BA-aaa13c07.g1 2400 5600 S_BA-aaa13c07

            my $low_val = int ($insert_size * 0.6);
            my $high_val = int ($insert_size * 1.6);

            $low_val = 0 if ($read_name =~ /_[tg]/);
            $con_fh->print("$fwd_read $rev_read $low_val $high_val $root_name\n");
        }
    }
    $con_fh->close;
    return 1;
}

sub _get_pcap_params {
    my ($self) = @_;
    #pcap.rep <pcap.input.fof> - params -y #proc -z #proc no
    return ' -l 50 -o 40 -s 1200 -w 90';
}

sub _get_bdocs_params {
    #don't need options for now but will need them later
    #bdocs.rep <pcap.input.fof> -y #proc -z (#bjobs)
}

sub _get_bclean_params {
    #don't need options for now but will need them later
    #bclean.rep <pcap.input.fof> -y #proc -w #bdoics jobs
}

sub _get_bcontig_params {
    my ($self) = @_;
    return ' -e 1 -f 2 -g 6 -k 20 -l 120 -s 4000 -w 180 -p 82 -t 3'
	unless $self->bconsen_params;
    if ($self->bconsen_params =~ /^relaxed/i)
    {
	return '-e 1 -f 2 -g 8 -k 20 -l 120 -p 82 -s 4000 -t 3 -w 180';
    }
    elsif ($self->bconsen_params =~ /more\s+relaxed/)
    {
	return '-e 1 -f 2 -g 2 -k 9 -l 120 -p 82 -s 4000 -t 3 -w 180';
    }
    elsif ($self->bconsen_params =~ /stringent/)
    {
	return '-e 1 -f 2 -g 2 -k 1 -l 120 -p 90 -s 4000 -t 3 -w 180';
    }
    else
    {
	#run some checks to make sure correct params
	return $self->bconsen_params;
    }
}

sub _get_bconsen_params {
    #don't need options for now but will need them later
    #bconsen <pcap.input.fof> -y #proc -z #proc no no
}

sub _get_bform_params {
    #don't need options for now but will need them later
    #bform <pcap.input.fof.pcap> -y #jobs
}

#TODO: may need to add more stringent error checking for the functions below
sub run_pcap {
    my ($self) = @_;
    my $dir = $self->data_path;
	$self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
#   my $params = $self->_get_pcap_params;
    my $ec = system ("pcap.rep.test ./".$self->project_name." ".$self->_get_pcap_params);
    $self->error_message("pcap.rep.test returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bdocs {
    my ($self) = @_;
    my $dir = $self->data_path;
	$self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
#   my $params = $self->_get_pcap_params;
    my $ec = system ("bdocs.rep $dir/edit_dir/".$self->project_name);
    $self->error_message("bdocs.rep returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bclean {
    my ($self) = @_;
    my $dir = $self->data_path;
	$self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
#   my $params = $self->_get_pcap_params;
    my $ec = system ("bclean.rep $dir/edit_dir/".$self->project_name);
    $self->error_message("bclean.rep returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bcontig {
    my ($self) = @_;
    my $dir = $self->data_path;
	$self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
#    my $params = $self->_get_bcontig_params;
    my $ec = system ("bcontig.rep $dir/edit_dir/".$self->project_name." ".$self->_get_bcontig_params);
    $self->error_message("bcontig.rep returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bconsen {
    my ($self) = @_;
    my $dir = $self->data_path;
	$self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
#    my $params = $self->_get_pcap_params;
    my $ec = system ("bconsen.test $dir/edit_dir/".$self->project_name);
    $self->error_message("bconsen.test returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bform {
    my ($self) = @_;
    my $dir = $self->data_path;
    $self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
#   my $params = $self->_get_pcap_params;
    my $ec = system ("bform $dir/edit_dir/".$self->project_name.".pcap ");
    $self->error_message("bform returned exit code $ec\n") and return if $ec;

    return 1;
}

#below three can run separately from pcap as a group
sub create_gap_file {
    my ($self) = @_;
    my $dir = $self->data_path;
    $self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
    my $sctg_file = 'supercontigs'; #this is a bform output file
    $self->error_message ("Could not find supercontigs file") and return unless -s $sctg_file;
    #this is a simple program that can be written in but for now ..
    my $gap_file = 'gap.txt';
    my $ec = system ("/gscuser/kkyung/bin/process_sctg_gap_file.pl supercontigs 1 > $gap_file");
    $self->error_message ("create_gap_file returned $ec\n") and return if $ec;
    return 1;
}

sub create_agp_file {
    my ($self) = @_;
    my $dir = $self->data_path;
    $self->error_message ("Could not change dir") and return if (!chdir("$dir/edit_dir"));
    my $contigs_bases_file = 'contigs.bases';
    my $gap_file = 'gap.txt';
    $self->error_message ("Could not find contigs.bases file") and return unless -s $contigs_bases_file;
    $self->error_message ("Could not find gap.txt file") and return unless -s $gap_file;
    my $sctg_agp_file = 'supercontigs.agp';
    my $ec = system ("create_agp_fa.pl -input $contigs_bases_file -agp $sctg_agp_file -gapfile $gap_file");
    $self->error_message ("create_agp_fa.pl returned $ec") and return if $ec;
    return 1;
}

sub create_sctg_fa_file {
    my ($self) = @_;
    my $dir = $self->data_path;
    $self->error_message ("Could not change dir") and return if (!chdir("$dir/edit_dir"));
    my $agp_file = 'supercontigs.agp';
    $self->error_message ("Cound not find $agp_file") and return unless -s $agp_file;
    my $blast_db = 'contigs.bases'.'.blastdb';
    $self->error_message () and return unless -s $blast_db;
    my $sctg_fasta_file = 'supercontigs.fa';
    my $ec = system ("create_fa_file_from_agp.pl $agp_file $sctg_fasta_file $blast_db");
    $self->error_message ("create_fa_file_from_agp returned $ec") and return if $ec;
    return 1;
}

sub create_stats_file
{
    my ($self) = @_;
    my $dir = $self->data_path;
    use Cwd;
    $self->error_message ("Could not change dir") and return if (!Cwd::chdir("$dir/edit_dir"));
    my $ec = system ("/gscuser/kkyung/bin/create_asm_stats_files.pl");
    $self->error_message("create_asm_stats_files.pl returned $ec") and return if $ec;
    return 1;
}

sub run_stats
{
    my ($self) = @_;
    my $dir = $self->data_path;
    $self->error_message ("Could not change dir") and return if (!Cwd::chdir("$dir/edit_dir"));
    my $ec = system ("/gscuser/kkyung/bin/run_asm_stats.pl -all");
    $self->error_message("run_asm_stats.pl returned $ec") and return if $ec;
    return 1;
}

sub load_config_file
{
    my ($self) = @_;
    my $config_file = $self->config_file;
    $self->status_message("Loading config file.");
    my $fh = IO::File->new("<$config_file");
    $self->error_message("unable to open $config_file") and return unless $fh;
    while (my $line = $fh->getline)
    {
	chomp $line;
	next if $line =~ /^\s+$/;
	if ($line =~ s/DATA_PATH:\s+//)
	{
	    $self->project_path = $line unless (defined $self->project_path);
	}
	elsif ($line =~ s/PROJECT_NAME:\s+//)
	{
	    $self->project_name = $line unless (defined $self->project_name);
	}
	elsif ($line =~ s/ASSEMBLY_VERSION:\s+//)
	{
	    $self->assembly_version = $line unless (defined $self->assembly_version);
	}
	elsif ($line =~ s/NUMBER_OF_JOBS:\s+//)
	{
	    $self->number_of_jobs = $line unless (defined $self->number_of_jobs);
	}	
	elsif ($line =~ s/PCAP_REP_PARAMS:\s+//)
	{
	    $self->pcap_rep_params = $line unless (defined $self->pcap_rep_params);
	}
	elsif ($line =~ s/BCONSEN_PARAMS:\s+//)
	{
	    $self->bconsen_params = $line unless (defined $self->bconsen_params);
	}
	else
	{
	    $self->error_message("incorrect config file line format: $line") and return;
	}
    }
    return 1;
}
1;

