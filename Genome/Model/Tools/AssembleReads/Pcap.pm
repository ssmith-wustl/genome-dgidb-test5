
package Genome::Model::Tools::AssembleReads::Pcap;

use strict;
use warnings;

use lib '/gscuser/kkyung/svn/pm';

use above "Genome"; 
use IO::File;
use File::Basename;
use GSC::IO::Assembly::StatsFiles; 
use GSC::IO::Assembly::Stats;                
use Data::Dumper;
use PP::LSF;
use Bio::SeqIO;
use Bio::Seq::Quality;
use Bio::Seq::SequenceTrace;
use Finishing::Assembly::Phd::Exporter;
use Finishing::Assembly::Factory;


class Genome::Model::Tools::AssembleReads::Pcap {
    is => 'Command',                       
    has => [  
	      project_name     => { 
		                   type => 'String',
				   doc => "project name"
			          },
	      data_path        => {
		                   type => 'String',
				   is_transient => 1,
				   doc => "path to the data"
				  },
              pcap_run_type    => {  
		                   type => 'String',
				   is_optional => 1,
				   doc => "normal poly 454_raw_data"
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
	      assembly_date    => {
		                   type => 'String',
				   doc => "assembly date",
			          },
	      config_file      => {
		                   type => 'String',
                                   doc => "configeration file",
                                   is_optional => 1,
	                          },
	      parameters       => {
		                   type => 'String',
				   doc => "bconsen parameters",
			          },
	      existing_data_only => {
		                     type => 'String',
				     is_optional => 1,
				     doc => "use only data already in project dir",
				   }
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

#this method does two things to keep date consistant
sub _project_path
{
    my ($self) = shift;
    my $disk_dir = $self->data_path;
    $self->error_message ("Unable to access $disk_dir") and return
	unless -d $disk_dir;
    my $date;
    chomp ($date = `date +%y%m%d`) unless ($date = $self->assembly_date);
    my $asm_version = $self->assembly_version;
    my $organism_name = $self->project_name;
    my $project_dir_name = $organism_name.'-'.$asm_version.'_'.$date.'.pcap';

    $self->{project_path} = $disk_dir.'/'.$project_dir_name;
    $self->{pcap_root_name} = $organism_name.'-'.$asm_version.'_'.$date;

    return 1;
}

sub create_project_directories
{
    my ($self) = @_;
    $self->_project_path;
    my $path = $self->{project_path};

    umask 002;
    mkdir "$path" unless -d $path;

    unless (-d "$path")
    {
        $self->error_message ("failed to create $path : $!");
        return;
    }

    foreach my $sub_dir (qw/ edit_dir input output phd_dir chromat_dir blastdb acefiles ftp read_dump/) {
	next if -d "$path/$sub_dir";
        mkdir "$path/$sub_dir";
        unless (-d "$path/$sub_dir")
        {
            $self->error_message ("failed to create $path/$sub_dir : $!");
            return;
        }
    }
    return 1;
}

sub resolve_data_needs
{
    my ($self) = @_;

    return 1 if $self->existing_data_only eq 'yes';
    
    $self->error_message ("Unable to get read prefixes") and return 
	unless $self->get_read_prefixes;

    $self->error_message ("Unalbe to dump reads") and return
	unless $self->dump_reads;

    return 1;
}

sub get_read_prefixes
{
    my ($self) = @_;

    my $organism_name = $self->project_name;

    my $valid_names = $self->get_valid_db_org_names;

    #create pattern match to grep the db name

    my $regex_pat = $organism_name;

    $regex_pat =~ s/[_|\s+]/\\s+/g;

#   print $regex_pat."\n";

    #consider doing this if we can have organism names inputed with spaces between names
    #$organism_name =~ s/\s+/\\s+/;

    chomp ( my @tmp = grep (/^$regex_pat$/i, @$valid_names) );

    $self->error_message("\nMultiple organism pattern match found ". map {$_} @tmp) and
	return if scalar @tmp > 1;

    $self->error_message("Unable to find match for $organism_name\n") and
	return if scalar @tmp == 0;

    my $prefixes = $self->get_read_prefixes_for_organism ($tmp[0]);

#   print map {$_."\n"} @$prefixes;

    #add in codes to exclude specific prefixes
    #since this is needed regulary

#    $self->dump_reads($prefixes);

    $self->{read_prefixes} = $prefixes;

    return 1;
}

sub get_read_prefixes_for_organism
{
    my ($self, $db_org_name) = @_;

    my $query = "select dr.dna_resource_prefix prefix, o.organism_name name ".
	        "from dna_resource dr ".
                "join entity_attribute_value eav on eav.entity_id = dr.dr_id ".
                "join organism o on o.org_id = eav.value ".
                "join dna_pse dpse on dpse.dna_id = dr.dr_id ".
                "where eav.attribute_name = 'org id' ".
                "and o.organism_name = '$db_org_name'";

    #there's probably better ways to do this
    my @prefixes = `sqlrun "$query" --nocount --noheader`;

    $self->error_message("\nQuery failed for $db_org_name\n") and return
	unless scalar @prefixes > 1;

    #query output looks like this grab first column

    #AHAL   Pristionchus pacificus
    #AHAA   Pristionchus pacificus
    #AHAB   Pristionchus pacificus
    #AHAC   Pristionchus pacificus

    @prefixes = map {$_ =~ /^(\S+)\s+/} @prefixes;

    return \@prefixes;
}

sub get_valid_db_org_names
{
    my ($self) = @_;
    my $org_name_query = "select ORGANISM_NAME from organism order by organism_name";

    #I'm sure there's a better way to do this  #use GSCApp ???
    my @names = `sqlrun "$org_name_query" --nocount --noheader`;
    $self->error_message("\nNo valid org names returned\n") and return
	unless @names;
    chomp (my @new = map {join ' ', $_} @names);
    return \@new;
}

sub dump_reads {
    my ($self) = @_;

    chomp (my $date = `date +%y%m%d`);

    my $read_dump_dir = $self->{project_path}.'/read_dump';

    my $edit_dir = $self->{project_path}.'/edit_dir';

    my $prefixes = $self->{read_prefixes};

    foreach my $prefix (@$prefixes)
    {
	my $re_id_file = $read_dump_dir.'/'.$prefix.'.'.$date.'.re_id';

	my $fasta_file = $edit_dir.'/'.$prefix.'.'.$date.'.fasta';

	my $qual_file = $edit_dir.'/'.$prefix.'.'.$date.'.fasta.qual';

	my $query = "sqlrun \"select re_id from sequence_read sr join funding_category f on ".
	            "f.fc_id = sr.fc_id where f.dna_resource_prefix = \'$prefix\' and ".
	            "sr.pass_fail_tag = \'PASS\'\" --instance=warehouse --parse > $re_id_file";

	$self->error_message("$query failed") and return if system ("$query");
  
	next unless -s $re_id_file > 0;

	#put in codes to fire this off to the queue if there are lots of reads

	$query = "seq_dump --input-file $re_id_file --output type=qual,file=$qual_file ".
	          "--output type=fasta,file=$fasta_file,maskq=0,maskv=1,nocvl=35";

	$self->error_message("$query failed") and return if system ("$query");

	#zip files
	$self->error_message("gzip fasta file failed") and return
	    if system ("gzip $fasta_file");

	$self->error_message("gzip qual file failed") and return
	    if system ("gzip $qual_file");

	next;

	#may need a way to prevent this for really big assemblies

	if ($self->dump_traces)
	{
	    my $phd_dir = $self->{project_path}.'/phd_dir';

	    my $chr_dir = $self->{project_path}.'/chromat_dir';

	    $query = "seq_dump --input-file $re_id_file --output type=phd,dir=$phd_dir ".
		     "--output type=scf,dir=$chr_dir";
	    
	    $self->error_message("$query failed") and return
		if system ("$query");
	}
    }

    return 1;
}

sub create_fake_phds
{
    my ($self) = @_;

    my $edit_dir = $self->{project_path}.'/edit_dir';

    my $phd_dir = $self->{project_path}.'/phd_dir';

    my @fastas = glob ("$edit_dir/*fasta.gz");

    foreach my $fasta (@fastas)
    {
	chomp $fasta;

	#make sure each fasta has corrisponding qual file
	my ($root_name) = $fasta =~ /(\S+)\.gz$/;
	my $qual = $root_name.'.qual.gz';
	$self->error_message ("$fasta does not have a qual file") and next
	    unless -s $qual;

	#exclude gsc read fastas since phd for those should be dumped from db
	next if $self->_are_gsc_reads ($fasta);
	
	my $dir = $self->{project_path};

	my $cmd = "perl -e \"use lib \'/gscuser/kkyung/svn/pm\';
                   use Genome::Model::Tools::AssembleReads::Pcap;
                   Genome::Model::Tools::AssembleReads::Pcap->create_454_phds(\'$fasta\', \'$qual\', \'$dir\');\"";

	my $job = PP::LSF->run
	(
	     pp_type => 'lsf',
             command => $cmd,
             q       => 'long',
             J       => "$fasta.MAKE_PHD",
             n       => 1,
             u       => $ENV{USER}.'@watson.wustl.edu',    
	);

	$self->error_message("Unable to create LSF job for $cmd") and return
	    unless $job;

	print "submitted lsf job to make phds for $fasta\n" if $job;

    }
    return 1;
}

sub create_454_phds
{
    my ($self, $fasta, $qual, $dir) = @_;

    #it should get dir from $self->{project_path} but had problems

    my $edit_dir = $dir.'/edit_dir';
    my $phd_dir = $dir.'/phd_dir';

    chdir "$edit_dir";

    my $f_fh = IO::File->new("zcat $fasta |");
    my $f_hash = {};
    my $f_io = Bio::SeqIO->new(-format => 'fasta', -fh => $f_fh);

    while (my $f_seq = $f_io->next_seq)
    {
	my $read = $f_seq->primary_id;
	$f_hash->{$read}->{seq} = $f_seq->seq;
    }

    $f_fh->close;
    my $q_fh = IO::File->new("zcat $qual |");
    my $q_io = Bio::SeqIO->new(-format => 'qual', -fh => $q_fh);

    #hard coded for a reason
    my $time = 'Tue Jan 25 12:00:00 2007';

    while (my $seq = $q_io->next_seq)
    {
	my $read = $seq->primary_id;

	if (exists $f_hash->{$read})
	{
	    my %attr = 
		(
		 name        => $read,
		 base_string => $f_hash->{$read}->{seq},
		 qualities   => $seq->qual,
		 comments    =>
		               {
				chromat_file          => $read,
				phred_version         => 'NA',
				call_method           => '454',
				quality_levels        => 99,
				time                  => $time,
				chem                  => 'unknown',
				dye                   => 'unknown',
				trace_array_min_index => 0,
				trace_array_max_index => 4647,
			       }, 
		);
    
	    my $phd_file = $phd_dir.'/'.$read.'.phd.1';
	    
	    my $factory = Finishing::Assembly::Factory->connect('source');
	    my $rfo = $factory->create_assembled_read(%attr);
	    my $xporter = Finishing::Assembly::Phd::Exporter->new (
							       file => $phd_file,
							       read => $rfo,
					       );
	    my $out = $xporter->execute;
	    $self->error_message("Phd export failed") and return
		unless $out;
	}
    }

    $q_fh->close;

    return 1;
}


sub _are_gsc_reads
{
    my ($self, $fasta) = @_;
    my $fh = IO::File->new("zcat $fasta |");
    $self->error_message("Unable to create file handle for $fasta") and exit (1)
	unless $fh;
    while (my $line = $fh->getline)
    {
	if ($line =~ /^>/)
	{
	    return unless $line =~ /CHROMAT_FILE/;
	    return unless $line =~ /PHD_FILE/;
	    return unless $line =~ /TIME/;
	    last;
	}
    }
    $fh->close;
    return 1;
}


sub create_pcap_input_fasta_fof
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    #return 1 if file already exists to pick up where left off??

    my $input_fof = $self->{pcap_root_name};

    my @fastas = glob ("$dir/edit_dir/*fasta.gz");

    $self->error_message("Could not find any fasta files") and return
	if scalar @fastas == 0;

    my $fh = IO::File->new(">$dir/edit_dir/$input_fof");

    $self->error_message ("Unable to create pcap input file\n") and return
	unless $fh;

    foreach my $file (@fastas)
    {
	my $name = basename $file;
	$name =~ s/\.gz$//;
        $fh->print ("$name\n");
    }
    $fh->close;

    return 1;
}


#this need to be able to differentiate 454 from reg read files
#and just cat the 454 constraint files together.

sub calc_insert_std_dev
{
    my ($self, $line) = @_;
    
}

sub create_constraint_file {
    my ($self) = @_;

    my $dir = $self->{project_path};

    my $con_file = $self->{pcap_root_name}.'.con';

    my $con_fh = IO::File->new(">$dir/edit_dir/$con_file");

    $self->error_message("Unable to create con file file handle") and return
	unless $con_fh;

    my @lib_infos;

    my @con_files = glob ("$dir/edit_dir/*.con");

    #cat all con files together
    #update the lib file
    if (@con_files)
    {
	foreach my $file (@con_files)
	{
	    next unless -s $file;
	    my $fh = IO::File->new("<$file");
	    while (my $line = $fh->getline)
	    {
		next if $line =~ /^\s+$/;
		chomp $line;
		my @tmp = split (/\s+/, $line);

		#if lib info exists in con file so just append
		if (scalar @tmp == 6)
		{
		    #this is hard coded in for now
		    #there are no info about insert size
		    #in fasta files so these are std numbers
		    #check to see if this is raw 454 data

		    if (my ($low_val, $high_val) = $tmp[5] =~ /Lib\.(\d+)_(\d+)$/)
		    {
			
		    }

		    my $lib_info = $tmp[5]." 4000 1500";
		    push @lib_infos, $lib_info unless grep (/^$lib_info$/, @lib_infos);

		    $con_fh->print("$line\n");
		}

		#lib info does not exist in con file make it and append
		elsif (scalar @tmp == 5)
		{
		    my $lib_name = 'Lib_'.$tmp[2].'_'.$tmp[3];
		    my $insert_size = int ($tmp[2] + $tmp[3] / 2);
		    my $std_dv = int ($insert_size * 0.56);
		    my $lib_info = "$lib_name $insert_size $std_dv";

		    push @lib_infos, $lib_info unless grep (/^$lib_info$/, @lib_infos);
		    $con_fh->print("$line $lib_name\n");
		}
		#con file should have 5 or 6 columns only
		else
		{
		    $self->error_message("Incorrect con file line format: $line");
		    next;
		}
	    }
	    $fh->close;
	}
    }

    my @fastas = glob ("$dir/edit_dir/*fasta.gz");

    foreach my $file (@fastas)
    {
	my $fh = IO::File->new ("zcat $file |");
        $self->error_message ("Unable to read $file\n") and return
	    unless $fh;

	my $query = $file;
	$query =~ s/(\.PE)?\.fasta\.gz$/\.con/;

	if (grep (/^$query$/, @con_files))
	{
	    $fh->close;
	    next;
	}

        while(my $line = $fh->getline)
        {
            next unless ($line =~ /^>/);
            my ($read_name) = $line =~ /^>(\S+)\s+/;
            my ($insert_size) = $line =~ /INSERT_SIZE:\s+(\d+)/;
            my ($root_name, $extension) = $read_name =~ /^(\S+)\.[bg](\d+)$/;

	    $self->error_message("Unable to get constraint info for $read_name") and next
		unless (defined $insert_size && defined $read_name && defined $root_name);

            my $fwd_read = $root_name.'.b'.$extension;
            my $rev_read = $root_name.'.g'.$extension;

            #lines should look like this
            #S_BA-aaa13c07.b1 S_BA-aaa13c07.g1 2400 5600 S_BA-aaa13c07 lib.2400_5600

            my $low_val = int ($insert_size * 0.6);
            my $high_val = int ($insert_size * 1.6);
	    my $std_dev = int ($insert_size * 0.56);

            $low_val = 0 if ($read_name =~ /_[tg]/);

	    my $lib_info = 'Lib.'.$low_val.'_'.$high_val;

            $con_fh->print("$fwd_read $rev_read $low_val $high_val $root_name $lib_info\n");

	    my $lib_info_val = $lib_info.' '.$insert_size.' '.$std_dev;

	    #creating the lib file at the same time to avoid repetitative coding
	    push @lib_infos, $lib_info_val unless grep (/^$lib_info_val$/, @lib_infos);
        }
	$fh->close;
    }
    $con_fh->close;

    my $lib_file = $self->{pcap_root_name}.'.lib';
    my $lib_fh = IO::File->new(">$dir/edit_dir/$lib_file");
    $self->error_message("Unable to create lib file file handle") and return
	unless $lib_fh;

    foreach my $info (@lib_infos)
    {
	$lib_fh->print("$info\n");
    }

    $lib_fh->close;

    return 1;
}

sub resolve_pcap_run_type
{
    my ($self) = @_;

    #types: 454_raw     => .rep.454
    #       normal      => .rep
    #       poly        => .rep.poly (bcontig only, all else .rep)

    my @types = qw/ normal poly raw_454_data /;

    $self->error_message("pcap run type must be 454_raw or poly") and return
	if $self->pcap_run_type and grep (/^$self->pcap_run_type$/, @types);

    my $ext = '.rep';

    $ext = '.rep.454' if $self->pcap_run_type eq '454_raw';

    my @progs = qw/ pcap bdocs bcontig bconsen /;

    foreach my $prog (@progs)
    {
	$self->{$prog.'_type'} = $prog.$ext;
    }

    $self->{bcontig_type} = 'bcontig.rep.poly' if $self->pcap_run_type eq 'poly';

    return 1;
}

sub _get_pcap_params {
    my ($self) = @_;
    #pcap.rep <pcap.input.fof> - params -y #proc -z #proc no
    #this is the same for all runs for now
    #will have to change for bigger assemblies
    return ' -l 50 -o 40 -s 1200 -w 90';
}

sub _get_bdocs_params {
    #don't need options for now but will need them later
    #bdocs.rep <pcap.input.fof> -y #proc -z (#bjobs)
    #no params needed for small assemblies
}

sub _get_bclean_params {
    #don't need options for now but will need them later
    #bclean.rep <pcap.input.fof> -y #proc -w #bdoics jobs
    #no params needed for small assemblies
}

sub _get_bcontig_params
{
    my ($self) = @_;

    #for now don't allow users to input own params
    #since it's only needed for bigger assemblies

    my @param_types = qw / relaxed more_relaxed stringent /;

    $self->error_message("parameter must be relaxed, more_relaxed or stringent") and return
	unless grep (/^$self->parameters$/, @param_types);

    if ($self->pcap_run_type eq '454_raw')
    {
	return '-e 0 -f 2 -g 8 -k 20 -l 75 -p 82 -q 0 -s 1400 -t 2 -w 350'
	    if $self->parameters eq 'relaxed';

	return '-e 0 -f 2 -g 8 -k 20 -l 75 -p 82 -q 0 -s 1400 -t 2 -w 350'
	    if $self->parameters eq 'more_relaxed';

	return '-e 0 -f 2 -g 8 -k 20 -l 75 -p 82 -q 0 -s 1400 -t 2 -w 350'
	    if $self->parameters eq 'stringent';	
    }
    else
    {
	return '-e 1 -f 2 -g 8 -k 20 -l 120 -p 82 -s 4000 -t 3 -w 180'
	    if $self->parameters eq 'relaxed';

	return '-e 1 -f 2 -g 2 -k 9 -l 120 -p 82 -s 4000 -t 3 -w 180'
	    if $self->parameters eq 'more_relaxed';

	return '-e 1 -f 2 -g 2 -k 1 -l 120 -p 90 -s 4000 -t 3 -w 180'
	    if $self->parameters eq 'stringent';
    }

    return;
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
sub run_pcap
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    $self->error_mesage("Could not change dir") and return
	if ( ! chdir("$dir/edit_dir") );

    my $pcap_type = $self->{pcap_type};

    my $ec = system ("pcap.rep.test ./".$self->{pcap_root_name}." ".$self->_get_pcap_params);

    $self->error_message("pcap.rep.test returned exit code $ec\n") and return if $ec;

    return 1;
}

sub run_bdocs {
    my ($self) = @_;
    my $dir = $self->{project_path};
    $self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
    my $ec = system ("bdocs.rep $dir/edit_dir/".$self->{pcap_root_name});
    $self->error_message("bdocs.rep returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bclean {
    my ($self) = @_;
    my $dir = $self->{project_path};
    $self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
    my $ec = system ("bclean.rep $dir/edit_dir/".$self->{pcap_root_name});
    $self->error_message("bclean.rep returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bcontig {
    my ($self) = @_;
    my $dir = $self->{project_path};
    $self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
    my $ec = system ("bcontig.rep $dir/edit_dir/".$self->{pcap_root_name}." ".$self->_get_bcontig_params);
    $self->error_message("bcontig.rep returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bconsen {
    my ($self) = @_;
    my $dir = $self->{project_path};
    $self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
    my $ec = system ("bconsen.test $dir/edit_dir/".$self->{pcap_root_name});
    $self->error_message("bconsen.test returned exit code $ec\n") and return if $ec;
    return 1;
}

sub run_bform {
    my ($self) = @_;
    my $dir = $self->{project_path};
    $self->error_mesage("Could not change dir") and return if(!chdir("$dir/edit_dir"));
    my $ec = system ("bform $dir/edit_dir/".$self->{pcap_root_name}.".pcap ");
    $self->error_message("bform returned exit code $ec\n") and return if $ec;

    return 1;
}

#below three can run separately from pcap as a group
sub create_gap_file {
    my ($self) = @_;
    my $dir = $self->{project_path};
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
    my $dir = $self->{project_path};
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
    my $dir = $self->{project_path};
    $self->error_message ("Could not change dir") and return
	if (!chdir("$dir/edit_dir"));
    my $agp_file = 'supercontigs.agp';
    $self->error_message ("Cound not find $agp_file") and return
	unless -s $agp_file;
    my $blast_db = 'contigs.bases'.'.blastdb';
    $self->error_message ("") and return
	unless -s $blast_db;
    my $sctg_fasta_file = 'supercontigs.fa';
    my $ec = system ("create_fa_file_from_agp.pl $agp_file $sctg_fasta_file $blast_db");
    $self->error_message ("create_fa_file_from_agp returned $ec") and return
	if $ec;
    return 1;
}

sub create_stats_files
{
    my ($self) = @_;
    #stats files object
    my $sfo = GSC::IO::Assembly::StatsFiles->new(dir => $self->{project_path});
    $sfo->cache_stats;

    return 1;
}

sub run_stats
{
    my ($self) = @_;
    my $dir = $self->{project_path};
    $self->error_message ("Could not change dir") and return if (!Cwd::chdir("$dir/edit_dir"));
    my $ec = system ("/gscuser/kkyung/bin/run_asm_stats.pl -all -dir $dir/edit_dir");
    $self->error_message("run_asm_stats.pl returned $ec") and return if $ec;
    return 1;
}

#don't need this
sub create_post_asm_files
{
    my ($self) = @_;
    my $dir = $self->{project_path};
    #stats text object
    my $sto = GSC::IO::Assembly::Stats->new(dir => $self->{project_path});
    $sto->create_readinfo_file;
    $sto->create_insert_sizes_file;
    return 1;
}

sub create_stats
{
    my ($self) = @_;
    my $dir = $self->{project_path};
    my $sto = GSC::IO::Assembly::Stats->new(dir => $self->{project_path});
    $sto->print_stats;
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

