
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
	     disk_location =>       {
		                      type => 'String',
				      doc => "path to the data"
				     },

	     project_name =>        { 
		                      type => 'String',
				      doc => "project name"
			             },

	     
	     pcap_run_type =>       {  
		                      type => 'String',
				      is_optional => 1,
				      doc => "normal poly 454_raw_data"
				     },

	     read_prefixes =>        {
		                      type => 'String',
				      is_optional => 1,
				      doc => "dna prefix use to find reads"
			             },

	     assembly_version =>    {
		                      type => 'String',
				      is_optional => 1,
				      doc => "assembly version number",
	                             },

	     assembly_date =>       {
		                      type => 'String',
				      doc => "assembly date",
			             },

	     config_file =>         {
		                      type => 'String',
                                      doc => "configeration file",
				      is_optional => 1,
	                             },

	     parameter_setting =>   {
		                      type => 'String',
				      doc => "bconsen parameters",
 			             },

	     existing_data_only =>  {
		                      type => 'String',
				      is_optional => 1,
				      doc => "use only data already in project dir",
				     },

	     make_fake_phds =>       {
		                      type => 'String',
				      is_optional => 1,
 				      doc => "make fake phds for 454 data",
				     },
	     make_phd_ball =>        {
		                      type => 'String',
				      is_optional => 1,
				      doc => "make phd ball of each input fasta/qual set",
	                             }
	   ], 
};

sub parse_config_file
{
    my ($self) = @_;

    my $config_file = $self->config_file;

    my $fh = IO::File->new("<$config_file");
    $self->error_message("unable to open $config_file") and return
	unless $fh;

    my $tmp = {};

    my @keys;

    while ( my $line = $fh->getline)
    {
	next if $line =~ /^[\s+$|\#]/;

	chomp $line;

	next unless my ($key, $val) = $line =~ /^(\S+)\s*=\s*(\S+)\s*$/;

	$tmp->{lc $key} = $val;

	push @keys, $key;
    }

    $self->{config_params} = $tmp;

    return $tmp, \@keys;
}

sub load_config_params_and_execute
{
    my ($self) = @_;

    #redirecting self to load config params
    $self = Genome::Model::Tools::AssembleReads::Pcap->create ($self->{config_params});

    $self->execute;

    return 1;
}

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

sub execute
{
    my ($self) = @_;

    $self->status_message("Creating assembly directories");
    unless ($self->create_project_directories)
    {
	$self->error_message("Failed to create assembly directories");
	return;
    }

    $self->status_message("Resolving data needs");
    unless ($self->resolve_data_needs)
    {
	$self->error_message("Failed to resolve data needs");
	return;
    }

    $self->status_message("Resolving pcap data needs");
    unless ($self->resolve_pcap_run_type)
    {
	$self->error_message("Failed to resolve pcap run type");
	return;
    }


    if ($self->make_fake_phds)
    {
	$self->status_message("Creating fake phd files");
	unless ($self->create_fake_phds ('file'))
	{
	    $self->error_message("Failed to create jobs for phd files");
	    return;
	}
    }

    if ($self->make_phd_ball)
    {
	$self->status_message("Creating phd ball");
	unless ($self->create_fake_phds ('ball'))
	{
	    $self->error_message ("Failed to submit jobs for phd ball");
	    return;
	}

    }

    $self->status_message("Creating input/pcap fof file");
    unless ($self->create_pcap_input_fasta_fof)
    {
	$self->error_message("Failed to create input/pcap fof file");
	return;
    }

    $self->status_message("Creating constraint file");
    unless ($self->create_constraint_file)
    {
	$self->error_message("Failed to create constraint file");
	return;
    }

    $self->status_message("Running pcap.rep");
    unless ($self->run_pcap)
    {
	$self->error_message("Pcap.rep failed to run");
	return;
    }

    $self->status_message("Running bdocs");
    unless ($self->run_bdocs)
    {
	$self->error_message("bdocs failed to run");
	return;
    }


    $self->status_message("Running bclean");
    unless ($self->run_bclean)
    {
	$self->error_message("bclean failed to run");
	return;
    }

    $self->status_message("Running bcontig");
    unless ($self->run_bcontig)
    {
	$self->error_message("bcontig failed to run");
	return;
    }

    $self->status_message("Running bconsen");
    unless ($self->run_bconsen)
    {
	$self->error_message("bconsen failed to run");
	return;
    }

    $self->status_message("Running bform");
    unless ($self->run_bform)
    {
	$self->error_message("Failed to run bform");
	return;
    }

    #CREATE POST ASSEMBLY FILES

    $self->status_message("creating gap file");
    unless ($self->create_gap_file)
    {
	$self->error_message("failed to create gap file") and return;
    }

    $self->status_message("creating agp file");
    unless ($self->create_agp_file)
    {
	$self->error_message("failed to create agp file") and return;
    }

    $self->status_message("creating supercontigs fasta file");
    unless ($self->create_sctg_fa_file)
    {
	$self->error_message("failed to create supercontigs fasta file") and return;
    }


    #CREATE STATS

    $self->status_message("creating stats files");
    unless ($self->create_stats_files)
    {
	$self->error_message("failed to create stats files") and return;
    }

    sleep 120;#give stats file jobs time to complete

    $self->status_message("Creating readinfo.txt and insert_sizes files");
    unless ($self->create_post_asm_files)
    {
	$self->error_message("Failed to create post assembly files");
	return;
    }

    $self->status_message("Creating stats");
    unless ($self->create_stats)
    {
	$self->error_message("failed to run stats");
	return;
    }
    $self->status_message("Creating stats");

    #CLEAN UP

    #don't clean up for now ..need to make sure stats are done
    #before cleaning up
    return 1;

    $self->status_message("Assembly done .. cleanin up");
    unless ($self->clean_up)
    {
	$self->error_message("Assembly done but ailed to clean up");
	return;
    }

    return 1;
}

#this method does two things to keep date consistant
sub _project_path
{
    my ($self) = shift;
    my $disk_dir = $self->disk_location;
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

    #?? look at it later
    $self->_project_path;

    my $path = $self->{project_path};

    umask 002;
    mkdir "$path" unless -d $path;

    unless (-d "$path")
    {
        $self->error_message ("failed to create $path : $!");
        return;
    }

    foreach my $sub_dir (qw/ edit_dir input output phd_dir chromat_dir blastdb acefiles ftp read_dump/)
    {
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

    return 1 if $self->existing_data_only and $self->existing_data_only eq 'YES';
    
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

    #print $regex_pat."\n";

    #consider doing this if we can have organism names inputed with spaces between names
    #$organism_name =~ s/\s+/\\s+/;

    chomp ( my @tmp = grep (/^$regex_pat$/i, @$valid_names) );

    $self->error_message("\nMultiple organism pattern match found ". map {$_} @tmp) and
	return if scalar @tmp > 1;

    $self->error_message("Unable to find match for $organism_name\n") and
	return if scalar @tmp == 0;

    my $prefixes = $self->get_read_prefixes_for_organism ($tmp[0]);

    #print map {$_."\n"} @$prefixes;

    #add in codes to exclude specific prefixes
    #since this is needed regulary

    #$self->dump_reads($prefixes);

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

    #I'm sure there's a better way to do this 
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
    my ($self, $type) = @_;

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
                   Genome::Model::Tools::AssembleReads::Pcap->create_454_phds(\'$fasta\', \'$qual\', \'$dir\', \'$type\');\"";

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
    my ($self, $fasta, $qual, $dir, $type) = @_;

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

	    my $phd_file;
	    $phd_file = $phd_dir.'/'.$read.'.phd.1' if $type eq 'file';
	    $phd_file = $fasta.'.tmp_phd_ball' if $type eq 'ball';

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

    #cat all con files together then update the lib file

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

		#make sure these constraint values are numbers

		$self->error_message("Incorrect line format in $file, line $line") and return
		    unless $tmp[2] =~ /^\d+$/ and $tmp[3] =~ /^\d+$/;

		#if lib info exists in con file line so just append
		if (scalar @tmp == 6)
		{
		    if (my ($low_val, $high_val) = $tmp[5] =~ /Lib\.(\d+)_(\d+)$/)
		    {
			my $insert_size = int($high_val + $low_val / 2);
			my $std_dv = int($insert_size * 0.56);

			my $lib_info = $tmp[5]." $insert_size $std_dv";
			push @lib_infos, $lib_info unless grep (/^$lib_info$/, @lib_infos);
			
		    }
		    elsif ($tmp[5] eq 'G20_454_PE')
		    {
			#this is hard coded in for PE processed raw 454 data
			my $lib_info = 'G20_454_PE 4000 1500';
			push @lib_infos, $lib_info unless grep (/^$lib_info$/, @lib_infos);
		    }
		    else
		    {
			$self->error_message("Incorrect line format in $file, line $line") and return;
		    }
		    
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

    #go through fasta files and make constraint info

    my @fastas = glob ("$dir/edit_dir/*fasta.gz");

    foreach my $file (@fastas)
    {
	my $fh = IO::File->new ("zcat $file |");
        $self->error_message ("Unable to read $file\n") and return
	    unless $fh;

	#PE processed 454 data sets have their own con file so
	#don't look through those

	my $query = $file;

	$query =~ s/\.gz$/\.con/;

	$fh->close and next if ( grep (/^$query$/, @con_files) );

        while(my $line = $fh->getline)
        {
            next unless ($line =~ /^>/);
            my ($read_name) = $line =~ /^>(\S+)\s+/;
            my ($insert_size) = $line =~ /INSERT_SIZE:\s+(\d+)/;
            my ($root_name, $extension) = $read_name =~ /^(\S+)\.[bg](\d+)$/;

	    next unless (defined $insert_size && defined $read_name && defined $root_name);

#	    $self->error_message("Unable to get constraint info for $read_name") and next
#		unless (defined $insert_size && defined $read_name && defined $root_name);

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

    #lib file can not be blank so put something in
    $lib_fh->print("LINE 1000 6000\n");

    $lib_fh->print ( map {$_."\n"} @lib_infos );

    $lib_fh->close;

    return 1;
}

sub resolve_pcap_run_type
{
    my ($self) = @_;

    #types: 454_raw     => .rep.454
    #       normal      => .rep
    #       poly        => .rep.poly (bcontig only, all else .rep)

    my @types = qw/ NORMAL POLY RAW_454 /;

    my $type = $self->pcap_run_type;

    $self->error_message("pcap run type must be NORMAL, RAW_454 or POLY") and return
	unless $self->pcap_run_type and grep (/^$type$/, @types);

    my $ext = '.rep';

    $ext = '.rep.454' if $self->pcap_run_type eq 'RAW_454';

    foreach my $prog ( qw/ pcap bdocs bclean bcontig bconsen / )
    {
	 $self->{$prog.'_prog_type'} = $prog.$ext;
    }

    #not sure why but bdocs.rep.454 always runs out of memory so just use bdocs.rep for now
#   $self->{bdocs_prog_type} = 'bdocs.rep';

    #bconsen.rep.454 no longer exists
    $self->{bconsen_prog_type} = 'bconsen.rep.454.071214'
	if $self->pcap_run_type eq 'RAW_454';

    $self->{bcontig_prog_type} = 'bcontig.rep.poly'
	if $self->pcap_run_type eq 'POLY';
    
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

    my @param_types = qw / TEST NORMAL RELAXED MORE_RELAXED STRINGENT /;

    my $type = $self->parameter_setting;

    $self->error_message("Parameter must be NORMAL, RELAXED, MORE_RELAXED or STRINGENT") and return
	unless grep (/^$type$/, @param_types);

    if ($self->pcap_run_type eq '454_raw')
    {
	return '-e 0 -f 2 -g 6 -k 20 -l 120 -p 82 -s 4000 -t 3 -w 180'
	    if $self->parameter_setting eq 'NORMAL';

	return '-e 0 -f 2 -g 8 -k 20 -l 75 -p 82 -q 0 -s 1400 -t 2 -w 350'
	    if $self->parameter_setting eq 'RELAXED';

	return '-e 0 -f 2 -g 2 -k 9 -l 75 -p 82 -q 0 -s 1400 -t 2 -w 350'
	    if $self->parameter_setting eq 'MORE_RELAXED';

	return '-e 0 -f 2 -g 8 -k 20 -l 75 -p 82 -q 0 -s 1400 -t 2 -w 350'
	    if $self->parameter_setting eq 'STRINGENT';	
    }
    else
    {
	return '-e 1 -f 2 -g 6 -k 20 -l 120 -p 82 -s 4000 -t 3 -w 180'
	    if $self->parameter_setting eq 'NORMAL';

	return '-e 1 -f 2 -g 8 -k 20 -l 120 -p 82 -s 4000 -t 3 -w 180'
	    if $self->parameter_setting eq 'RELAXED';

	return '-e 1 -f 2 -g 2 -k 9 -l 120 -p 82 -s 4000 -t 3 -w 180'
	    if $self->parameter_setting eq 'MORE_RELAXED';

	return '-e 1 -f 2 -g 2 -k 1 -l 120 -p 90 -s 4000 -t 3 -w 180'
	    if $self->parameter_setting eq 'STRINGENT';
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
	unless ( chdir ("$dir/edit_dir") );

    my $pcap_prog = $self->{pcap_prog_type};

    my $ec = system ($pcap_prog.' '.$self->{pcap_root_name}.' '.$self->_get_pcap_params);

    $self->error_message("pcap.rep.test returned exit code $ec\n") and return
	if $ec;

    return 1;
}

sub run_bdocs
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    my $bdocs_prog = $self->{bdocs_prog_type};

    #not sure but but bdocs.rep.454 runs out of memory??
    $bdocs_prog = 'bdocs.rep';

    $self->error_mesage("Could not change dir") and return
	unless ( chdir ("$dir/edit_dir") );

    my $ec = system ($bdocs_prog.' '.$self->{pcap_root_name});

    $self->error_message("bdocs.rep returned exit code $ec\n") and return if $ec;

    return 1;
}

sub run_bclean
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    my $bclean_prog = $self->{bclean_prog_type};

    $self->error_mesage("Could not change dir") and return
	unless ( chdir ("$dir/edit_dir") );

    my $ec = system ($bclean_prog.' '.$self->{pcap_root_name});

    $self->error_message("bclean returned exit code $ec\n") and return
	if $ec;

    return 1;
}

sub run_bcontig
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    my $bcontig_prog = $self->{bcontig_prog_type};

    $self->error_mesage("Could not change dir") and return
	unless ( chdir ("$dir/edit_dir") );

    my $ec = system ($bcontig_prog.' '.$self->{pcap_root_name}." ".$self->_get_bcontig_params);

    $self->error_message("bcontig returned exit code $ec\n") and return if $ec;

    return 1;
}

sub run_bconsen
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    my $bconsen_prog = $self->{bconsen_prog_type};

    $self->error_mesage("Could not change dir") and return
	unless ( chdir ("$dir/edit_dir") );

    my $ec = system ($bconsen_prog.' '.$self->{pcap_root_name});

    $self->error_message("bconsen returned exit code $ec\n") and return
	if $ec;

    return 1;
}

sub run_bform
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    $self->error_mesage("Could not change dir") and return
	unless ( chdir("$dir/edit_dir") );

    my $ec = system ('bform '.$self->{pcap_root_name}.'.pcap ');

    $self->error_message("bform returned exit code $ec\n") and return
	if $ec;

    return 1;
}

#below three can run separately from pcap as a group
sub create_gap_file
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    $self->error_mesage("Could not change dir") and return
	unless ( chdir ("$dir/edit_dir") );

    #this is a bform output file
    $self->error_message ("Could not find supercontigs file") and return
	unless -s 'supercontigs';

    my ($ctgfrom, $gap_size);

    my $gap_fh = IO::File->new("> gap.txt");

    my $sc_fh = IO::File->new("< supercontigs");

    while (my $line = $sc_fh->getline)
    {
	chomp $line;
	if ($line =~ /^contig\s+Contig\S+$/)
	{
	    ($ctgfrom) = $line =~ /^contig\s+(Contig\S+)$/;
	}
	if ($line =~ /^gap\s+/)
	{
	    ($gap_size) = $line =~ /^gap\s+(-?\d+)/;
	    $gap_size = 10 if $gap_size < 10;

	    $gap_fh->print("$ctgfrom $gap_size\n");
	}
    }

    $sc_fh->close;

    $gap_fh->close;

    return 1;
}

sub create_agp_file
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    $self->error_message ("Could not change dir") and return
	unless ( chdir ("$dir/edit_dir") );

    $self->error_message ("Could not find contigs.bases file") and return
	unless -s 'contigs.bases';

    #gap.txt can be an empty file

    $self->error_message ("Could not find gap.txt file") and return
	unless -e 'gap.txt';

    my $ec = system ("create_agp_fa.pl -input contigs.bases -agp supercontigs.agp -gapfile gap.txt");

    $self->error_message ("create_agp_fa.pl returned $ec") and return if $ec;

    return 1;
}

sub create_sctg_fa_file
{
    my ($self) = @_;

    my $dir = $self->{project_path};

    $self->error_message ("Could not change dir") and return
	unless ( chdir ("$dir/edit_dir") );

    $self->error_message ("Cound not find supercontigs.agp file") and return
	unless -s 'supercontigs.agp';

    my $ec = system ("create_fa_file_from_agp.pl supercontigs.agp supercontigs.fa contigs.bases.blastdb");

    $self->error_message ("Unable to create supercontigs fasta file") and return
	if $ec;

    return 1;
}

sub create_stats_files
{
    my ($self) = @_;

    #stats files object
    my $sfo = GSC::IO::Assembly::StatsFiles->new(dir => $self->{project_path});

    $self->error_message("Unable to get stats file object") and return
	unless $sfo;

    $sfo->cache_stats;

    return 1;
}

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

sub clean_up
{
    my ($self) = @_;
    my $edit_dir = $self->{project_path}.'/edit_dir';

    chdir "$edit_dir";

    `mv *fasta.gz *qual.gz ../input`;
    `mv *blastdb.x* ../blastdb`;
    `mv contigs.bases contigs.quals supercontigs* reads.placed reads.unplaced ../output`;
    `cat *tmp_phd_ball > phd.ball` if $self->make_phd_ball;
    `\\rm *tmp_phd_ball` if $self->make_phd_ball;

    return 1;
}


1;
