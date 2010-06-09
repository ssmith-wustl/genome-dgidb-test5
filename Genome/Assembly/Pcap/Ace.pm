package Genome::Assembly::Pcap::Ace;

our $VERSION = 0.01;

use strict;
use warnings;
use Carp;
use base qw(Class::Accessor::Fast);
use Genome::Assembly::Pcap::Ace::Reader;
use Genome::Assembly::Pcap::Ace::Writer;
use Genome::Assembly::Pcap::Item;
use Genome::Assembly::Pcap::SequenceItem;
use Genome::Assembly::Pcap::Contig;
use Genome::Assembly::Pcap::Read;
use Genome::Assembly::Pcap::Tag;
use Genome::Assembly::Pcap::TagParser;
use Genome::Assembly::Pcap::Sources::Ace::Contig;
use Genome::Assembly::Pcap::Config;
use IO::File;
use IO::String;
use Storable;
use DBI;
use File::Basename;
use Cwd 'abs_path';
$Storable::Deparse = 1;
$Storable::Eval = 1;
#$Storable::forgive_me = 1;

Genome::Assembly::Pcap::Ace->mk_accessors(qw(_reader _writer _input _output _input_file _output_file dbh sth_create sth_rem sth_set sth_get sth_getcount db_type _init_db _keep_changes _db_dsn _assembly_name _db_file config _show_progress));



sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};
    bless ($self, $class);
	$self->_set_config( Genome::Assembly::Pcap::Config->new);
	$params{input_file} = abs_path( $params{input_file}) if exists $params{input_file};	
	$self->_input(delete $params{input});
    $self->_input_file(delete $params{input_file});
	$self->_input(IO::File->new($self->_input_file)) if(defined $self->_input_file);
	$self->_output(delete $params{output});
    $self->_output_file(delete $params{output_file});
	$self->_output(IO::File->new(">".$self->_output_file)) if(defined $self->_output_file);
    $self->_db_file($params{db_file});
		
	$self->_init_db(delete $params{init_db});
	$self->_keep_changes(delete $params{keep_changes});	
    $self->_show_progress(delete $params{show_progress});
    $self->_process_params(%params);	
	
	
	my $contig_group_name;
	if(defined $self->_input_file)
	{
		$contig_group_name = $self->_input_file;#allows for partitioning of data
	}
	elsif(defined $self->_assembly_name)
	{
		$contig_group_name = $self->_assembly_name;
	}
	else
	{
		$contig_group_name = $self->config->{default_assembly};
	}
    $self->{contigs} = {};
    $self->{assembly_tags} = {};
    $self->{sleep} = 1;
    $self->_reader ( Genome::Assembly::Pcap::Ace::Reader->new($self->_input));
	
    if($params{using_db})
    {
		$self->using_db(1);
        print STDERR "There was an error connecting to the database.\n" and return unless($self->_connect);
		$self->_create_tables; 
		my $sth = $self->dbh->prepare("select count(id) from ace_files where url = ?");           
        $sth->execute($contig_group_name);
        my $url_count = $sth->fetchrow_arrayref->[0];
        if($params{cc} && ($url_count>0))
        {
            my $delete_url = $self->dbh->prepare("delete from ace_files where id = ?");
            my $delete_items = $self->dbh->prepare("delete from items where asid = ?");
            my $get_id = $self->dbh->prepare("select id from ace_files where url = ?");
            $self->dbh->begin_work;  
		    while($params{cc} && ($url_count >0))
            {
                $get_id->execute($contig_group_name);
                my $id = $get_id->fetchrow_arrayref->[0];
                $delete_url->execute($id);
                $delete_items->execute($id);
                $sth->execute($contig_group_name);
                $url_count = $sth->fetchrow_arrayref->[0];
            }
            $self->dbh->commit;
        }
		if($url_count == 0)
		{
			$self->_init_db(1);
			$sth = $self->dbh->prepare("insert into ace_files (url) VALUES (?)");
			$sth->execute($contig_group_name);
			my $sth = $self->dbh->prepare("select id from ace_files where url = ?");
			$sth->execute($contig_group_name);
			$self->{asid} = $sth->fetchrow_arrayref->[0];					
		}
		else
		{
			my $sth = $self->dbh->prepare("select id from ace_files where url = ?");
			$sth->execute($contig_group_name);
			$self->{asid} = $sth->fetchrow_arrayref->[0];           
		}        
		
        if($self->db_type eq "SQLite")
        {		
            $self->sth_get( $self->dbh->prepare(qq{ select data from items where name = ? and asid = $self->{asid}}));
            $self->sth_getcount( $self->dbh->prepare(qq{ select count (name) from items where name = ? and asid = $self->{asid}}));              
            $self->sth_set( $self->dbh->prepare(qq{ insert or replace into items (name, data, type, count, asid) VALUES (?, ?, ?, ?, $self->{asid})}));
            $self->sth_rem( $self->dbh->prepare(qq{ delete from items where name = ? and asid = $self->{asid}}));
            $self->sth_set->execute("has_changed", 0, 0, 0) if($self->_init_db);           
        }
		elsif($self->db_type eq "mysql")
		{			
            $self->sth_get( $self->dbh->prepare(qq{ select data from items where name = ?}));
            $self->sth_getcount( $self->dbh->prepare(qq{ select count from items where name = ?}));              
            $self->sth_set( $self->dbh->prepare(qq{ insert into items (name, data, type, count, asid) VALUES (?, ?, ?, ?, $self->{asid}) on duplicate key update data = values(data), count = values(count)}));
            $self->sth_rem( $self->dbh->prepare(qq{ delete from items where name = ? and asid = $self->{asid}}));
            $self->sth_set->execute("has_changed", 0, 0, 0) if ($self->_init_db);		
		
		}
       
        $self->_build_index($self->_input) if ((defined $self->_input)&&($url_count==0));
        
		return $self;
        
    }
    else
    {
        $self->using_db(0);
    }   
        
    if(defined $self->_input && defined $self->_input_file && -f $self->_input_file.".index" )
    {
        $self->_load_index_from_file($self->_input_file.".index");
    }
    else
    {
        $self->_build_index($self->_input) if defined $self->_input;
    }
    
    return $self;
}

sub _derive_db_type_from_dsn
{
	my ($self) = @_;
	my ($db_type) = $self->_db_dsn =~ /.?:(.?):.+/;
	$self->db_type($db_type);
}

sub _process_params
{
	my ($self, %params) = @_;
	if(defined $params{db_dsn})
	{
		#if the user passed in a db_dsn, then that will be used regardless of what
		#db_type they specify
		$self->_db_dsn($params{db_dsn});
		$self->db_type($self->_derive_db_type_from_dsn);
		return;
	}
	elsif(defined $params{db_type})
	{
		$self->{db_type} = $params{db_type};	
	}
	
	if($self->{db_type} eq "SQLite")
	{
        if(defined $self->_db_file )
        {
            $self->_db_dsn("dbi:SQLite:".$self->_db_file);        
        }
		elsif(defined $self->_input_file )
		{
			$self->_db_dsn("dbi:SQLite:".$self->_input_file.".db");
		}
		else
		{
            warn "You probably don't want to use the default sqlite DSN, $self->{sqlite_def_dsn}.\n  if there are issues try deleting assembly.db\n";
			$self->_db_dsn( $self->{sqlite_def_dsn});
		}	
	}
	elsif($self->{db_type} eq "mysql")
	{
		$self->_db_dsn( $self->{mysql_def_dsn});
	}
	
	
}
sub _set_config
{
	my ($self,$config_obj) = @_;
	$self->{config_obj} = $config_obj;
	$self->{config} = $config_obj->{config};
	my $config = $self->{config};
	foreach my $key (keys %{$config})
	{
		$self->{$key} = $config->{$key};	
	}		
}

sub _create_tables
{
	my ($self) = @_;
	if($self->db_type eq "mysql")
	{
        return;#we shouldn't normally create mysql tables
		$self->sth_create ($self->dbh->prepare(qq{
			CREATE TABLE IF NOT EXISTS `items`(
  			  #`id` int(11) auto_increment NOT NULL,
			  `name` varchar(50) NOT NULL default '',
        	  `count` int, 
			  `type` char(10), 
			  `data` longblob, 
			  `asid` int(11) NOT NULL,
			  #PRIMARY KEY  (`id`),
			  PRIMARY KEY (`name`,`asid`)			  
			) ENGINE = InnoDB}));

    	$self->sth_create->execute;
    	$self->sth_create->finish;
                $self->sth_create ($self->dbh->prepare(qq{ 
			create index asid_index on items( `asid` )
		}));
		$self->sth_create->execute; 
		$self->sth_create->finish;
		$self->sth_create ($self->dbh->prepare(qq{ 
			CREATE TABLE IF NOT EXISTS `ace_files` ( 
			`id` int(11) auto_increment NOT NULL, 
			`url` varchar(256) NOT NULL default '',  
			PRIMARY KEY  (`id`),
			KEY `url` (`url`) #should probably be assembly name?
		) ENGINE = InnoDB}));
		$self->sth_create->execute; 
		$self->sth_create->finish;
	}
	elsif($self->db_type eq "SQLite")
	{
		$self->sth_create ($self->dbh->prepare(qq{
			CREATE TABLE if not exists `items` (  			  
			  `name` varchar(50) NOT NULL default '',
        	  `count` int, 
			  `type` char(10), 
			  `data` longblob, 
			  `asid` int(11) NOT NULL,			  
			  PRIMARY KEY (`name`,`asid`)			  
			) }));

    	$self->sth_create->execute;
    	$self->sth_create->finish;
		$self->sth_create ($self->dbh->prepare(qq{ 
			CREATE TABLE if not exists ace_files ( 
			`id` integer primary key autoincrement, 
			`url` varchar(256) NOT NULL default ''			
		) }));
		$self->sth_create->execute; 
		$self->sth_create->finish;
		$self->sth_create ($self->dbh->prepare(qq{ 
			create index if not exists url_index on ace_files( `url` )
		}));
		$self->sth_create->execute; 
		$self->sth_create->finish;
	
	}
}

sub _build_index
{
	my ($self, $fh) = @_;
	my %contigs;
	my @assembly_tag_indexes;
    my $old_hash = undef;
    my $old_contig = undef;
    my $first_bs = 1;
    my $found_bq = 0;
    my $found_qa = 0;
    my $found_af = 0;
    my $found_rd = 0;
	my $co_count = 0;
    $fh = $self->_input if (!defined $fh && defined $self->_input);
	
    if($self->using_db)
    {
		$self->dbh->begin_work;       
	}
	my %tag_hash;
	while(my $line = <$fh>)
	{
		if($line =~ /CT{/)
		{
			my $offset = (tell $fh) - length $line;
			my $first_length = length $line;
			$line = <$fh>;
			$line =~ s/^\s*// if $line =~ /\w/;
			my @tokens = split(/[ {]/,$line);			
            
			$old_hash = {offset => $offset, length => (length($line) + $first_length)};
						
			if(!defined $tag_hash{$tokens[0]}) {$tag_hash{$tokens[0]} = [];}
            push (@{$tag_hash{$tokens[0]}}, $old_hash); 
			
		}
		else
        {            
            $old_hash->{length} += length($line) if(defined($old_hash));
        }
	}
	$fh->seek(0,0);
	$old_hash = undef;
	
	while(my $line = <$fh>)
	{
		my $first_three = substr($line, 0,3);        
		if($first_three eq "BS ")
		{           
            my $offset = (tell $fh) - length $line;
            $old_hash = undef;            
            $old_contig->{base_segments}{offset} = $offset;
			for(my $i = 0;$i<$old_contig->{base_segments}{line_count};$i++)
			{
				my $line = <$fh>;			
			}            
			
			my $offset2 = tell $fh;
	        $old_contig->{base_segments}{length} = $offset2 - $old_contig->{base_segments}{offset};
            
		}
		elsif($first_three eq "AF ")
		{
			if($found_bq == 1)
            {
                $old_contig->{base_qualities}{length} = (tell $fh) - length($line) - $old_contig->{base_qualities}{offset};
                $found_bq = 0;
            }
			my @tokens = split(/[ {]/,$line);
            my $end = (tell $fh);			
			my $offset = $end - length $line;            
            $old_hash = { name => $tokens[1], offset => $offset };
            $old_contig->{reads}{$tokens[1]}{read_position}= $old_hash;
            $old_contig->{af_start} = $offset;
			for(my $i=1;$i<$old_contig->{read_count};$i++)
			{
				my $line = <$fh>;
                my $first_three = substr($line, 0,3);
                 if($first_three ne 'AF ')
                 {
                    print "Expected an AF but instead got $line";
                    $fh->seek(- length $line,1);
                    last;
                 }
				my @tokens = split(/[ {]/,$line);
            	my $end = (tell $fh);			
				my $offset = $end - length $line;            
            	$old_hash = { name => $tokens[1], offset => $offset };
            	$old_contig->{reads}{$tokens[1]}{read_position}= $old_hash;				
            }		
			
            $old_contig->{af_end} = (tell $fh);
            
		}
		elsif($first_three eq "RD ")
		{
			my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - length $line;
			if(!$found_rd)
			{
				$old_contig->{rd_start} = $offset ;			
            	$found_rd = 1;
			}
			$old_hash = { offset => $offset,
                          name => $tokens[1],
                          read_tags => [],
                          length => length($line)};
                        
                        
            $old_hash->{sequence}{offset} = (tell $fh);
			$fh->seek($tokens[2],1);
			$old_contig->{reads}{$tokens[1]}{read} = $old_hash;			
			
		}        
		elsif($first_three eq "CO ")
		{
			my @tokens = split(/[ {]/,$line);
            print "Indexing $tokens[1]...\n" if ($self->_show_progress);
			my $offset = (tell $fh) - length $line;			
            $old_contig->{contig_length} = $offset - $old_contig->{offset} if (defined $old_contig);
            $old_contig->{rd_end} = $offset if (defined $old_contig);
			if(defined $old_contig&&$self->using_db)
			{								
				$self->sth_set->execute($old_contig->{name}, Storable::freeze($old_contig), "Contig", scalar keys %{$old_contig->{reads}});    
            	$co_count++;
				if($co_count > 1000)
				{
					$self->dbh->commit;
					$self->dbh->begin_work;
					$co_count = 0;									
				}
			}
			$old_hash = { offset => $offset,
                              name => $tokens[1],
                              read_count => $tokens[3],
                              base_segments => {line_count => $tokens[4]},#\@base_segments,
                              contig_tags => [] ,
                              contig_loaded => 0 ,
                              length => length($line),
							  sequence_length => $tokens[2],
                              contig_length => length($line)};
			$old_hash->{contig_tags} = $tag_hash{$tokens[1]} if (exists $tag_hash{$tokens[1]});				  
            $old_contig = $old_hash;
            $contigs{$tokens[1]} = $old_hash if (!$self->using_db);
            $found_af = 0;
            $found_rd = 0;
			$fh->seek($tokens[2],1);
            							  
		}
		elsif(substr($first_three,0,2) eq "BQ")
        {
            my $offset = (tell $fh) - length $line;
            $old_contig->{base_qualities}{offset} = $offset; 
            $old_contig->{base_sequence}{length} = ($offset-1)-$old_contig->{offset};
			$found_bq = 1;
			$fh->seek($old_contig->{sequence_length}*2,1);
			
        }
		elsif($first_three eq "WA ")
		{
			my $offset = (tell $fh) - length $line;
            $old_hash = { offset => $offset, length => length($line) };
            $old_contig->{contig_length} = $offset - $old_contig->{offset} if (defined $old_contig);
			$old_contig = undef;
			push (@assembly_tag_indexes, $old_hash);
		}
		elsif($first_three eq "CT{")
		{
			my $offset = (tell $fh) - length $line;						
            if(defined $old_contig)
            {
				
                $old_contig->{contig_length} = $offset - $old_contig->{offset};
                $old_contig->{rd_end} = $offset;
				if($self->using_db)
				{
					$self->sth_set->execute($old_contig->{name}, Storable::freeze($old_contig), "Contig", scalar keys %{$old_contig->{reads}});    
			    }
				else
				{
					$contigs{$old_contig->{name}} = $old_contig;
				}
				$old_contig = undef;
            }
			$old_hash = {offset => $offset, length => length($line)};			
		}
		elsif(substr($line,0,3) eq "DS ")
		{
			my $offset = (tell $fh) - length $line;
        	$old_hash->{ds}{offset} = $offset;  
        	$old_hash->{length} = (tell $fh) - $old_hash->{offset};							
		}
		elsif(substr($line,0,3) eq "QA ")
		{
        	my $offset = (tell $fh) - length $line;
            if(!defined $offset|| !defined $old_hash->{offset})
            {
                print $old_hash->{name},"\n";
                print $line,"\n";
            }            
        	$old_hash->{qa}{offset} = $offset;
        	$old_hash->{sequence}{length} = ($offset - 1) - $old_hash->{sequence}{offset};
		    $old_hash->{length} = (tell $fh) - $old_hash->{offset};
        }
		elsif($first_three eq "RT{")
		{
			my $offset = (tell $fh) - length $line;
			my $first_length = length $line;
			$line = <$fh>;
			my @tokens = split(/[ {]/,$line);            
			$old_hash = {offset => $offset, length => (length($line)+ $first_length)};
			push (@{$old_contig->{reads}{$tokens[0]}{read}{read_tags}} ,$old_hash );	
			
		}		        
        else
        {            
            $old_hash->{length} += length($line) if(defined($old_hash));
        }
	}
    $old_contig->{rd_end} = ($fh->stat)[7] if (defined $old_contig);    
	$old_contig->{contig_length} = ($fh->stat)[7] - $old_contig->{offset} if (defined $old_contig);
    if($self->using_db)
    {
		if(defined $old_contig)
        {
			$self->sth_set->execute($old_contig->{name}, Storable::freeze($old_contig), "Contig", scalar keys %{$old_contig->{reads}});    						
        }
	    $self->sth_set->execute("assembly_tags", Storable::freeze({tags_loaded => 0, tag_indexes => \@assembly_tag_indexes}), "a_tags", 0);
        $self->dbh->commit;      
    }
    else
    {
        $self->{contigs} = \%contigs;
        $self->{assembly_tags} = {};
        $self->{assembly_tags}{tags_loaded} = 0;
        $self->{assembly_tags}{tag_indexes} = \@assembly_tag_indexes;   
    }    
}

sub _build_index_new
{
	my ($self, $fh) = @_;
	my %contigs;
	my @assembly_tag_indexes;
    my $old_hash = undef;
    my $contig = undef;
    my $first_bs = 1;
    my $found_bq = 0;
    my $found_qa = 0;
    my $found_af = 0;
    my $found_rd = 0;
	my $co_count = 0;
    if($self->using_db)
    {
        while(! defined $self->dbh->begin_work)
        {
            print $self->dbh->errstr."\n";
            $self->_sleep;
        }
	}
	
	while(my $line = <$fh>)
	{
		my $first_three = substr($line, 0,3);        
		if($first_three eq "CO ")
		{
			if(1)
			{
				$contig = $self->_build_contig_index($fh,$line);
			}
			else
			{
				$contig = $self->_build_empty_contig_index($fh,$line);
			}
			if($self->using_db)
			{
				$self->sth_set->execute($contig->{name}, Storable::freeze($contig), "Contig", scalar keys %{$contig->{reads}});    
            	$co_count++;
				if($co_count > 1000)
				{
					while(! defined $self->dbh->commit)
			        {
        			    print $self->dbh->errstr."\n";
        			    $self->_sleep;
        			}
					while(! defined $self->dbh->begin_work)
        			{
			            print $self->dbh->errstr."\n";
        			    $self->_sleep;
        			}
					$co_count = 0;									
				}
			}
			else
			{
            	$contigs{$contig->{name}} = $contig;
			}
		}
		
		elsif($first_three eq "WA ")
		{
			my $offset = (tell $fh) - length $line;
            $old_hash = { offset => $offset, length => length($line) };            
			push (@assembly_tag_indexes, $old_hash);
		}
		elsif($first_three eq "CT{")
		{
			my $offset = (tell $fh) - length $line;
			my $first_length = length $line;
			$line = <$fh>;
			$line =~ s/^\s*// if $line =~ /\w/;
			my @tokens = split(/[ {]/,$line);	            
			$old_hash = {offset => $offset, length => (length($line) + $first_length)};
			my $contig;
			if($self->using_db)
			{
				$self->sth_get->execute($tokens[0]);
				my $temp = $self->sth_get->fetchrow_arrayref->[0];
				$contig = Storable::thaw($temp, );
			}
			else
			{
				$contig = $contigs{$tokens[0]};
			}	
			
            push (@{$contig->{contig_tags}}, $old_hash); 
			if($self->using_db)
			{
				$self->sth_set->execute($contig->{name}, Storable::freeze($contig), "Contig", scalar keys %{$contig->{reads}});       
			}
		}				        
        else
        {            
            $old_hash->{length} += length($line) if(defined($old_hash));
        }
	}    
    if($self->using_db)
    {
        $self->sth_set->execute("assembly_tags", Storable::freeze({tags_loaded => 0, tag_indexes => \@assembly_tag_indexes}), "a_tags", 0);
        while(! defined $self->dbh->commit)
        {
            print $self->dbh->errstr."\n";
            $self->_sleep;
        }       
    }
    else
    {
        $self->{contigs} = \%contigs;
        $self->{assembly_tags} = {};
        $self->{assembly_tags}{tags_loaded} = 0;
        $self->{assembly_tags}{tag_indexes} = \@assembly_tag_indexes;   
    }    
}

sub _build_contig_index
{
	my ($self, $fh, $line, $file_offset) = @_;
	my %contigs;
	my @assembly_tag_indexes;
    my $old_hash = undef;
    my $contig = undef;
    my $first_bs = 1;
    my $found_bq = 0;
    my $found_qa = 0;
    my $found_af = 0;
    my $found_rd = 0;
	my $co_count = 0;
    $fh->seek($file_offset,0) if defined $file_offset;
	
	#build contig data structures
	my @tokens = split(/[ {]/,$line);
	my $offset = (tell $fh) - length $line;            

	$old_hash = { offset => $offset,
                      name => $tokens[1],
                      read_count => $tokens[3],
                      base_segments => {line_count => $tokens[4]},#\@base_segments,
                      contig_tags => [] ,
                      contig_loaded => 0 ,
					  contig_indexed => 1,
                      length => length($line),
					  sequence_length => $tokens[2],
                      contig_length => length($line)};
    $contig = $old_hash;    
    $found_af = 0;
    $found_rd = 0;
	$fh->seek($tokens[2],1);            							  
		
	while(my $line = <$fh>)
	{
		my $first_three = substr($line, 0,3);        
		if($first_three eq "BS ")
		{           
            my $offset = (tell $fh) - length $line;
            $old_hash = undef;            
            $contig->{base_segments}{offset} = $offset;
			for(my $i = 0;$i<$contig->{base_segments}{line_count};$i++)
			{
				my $line = <$fh>;			
			}            
			
			my $offset2 = tell $fh;
	        $contig->{base_segments}{length} = $offset2 - $contig->{base_segments}{offset};
            
		}
		elsif($first_three eq "AF ")
		{
			if($found_bq == 1)
            {
                $contig->{base_qualities}{length} = (tell $fh) - length($line) - $contig->{base_qualities}{offset};
                $found_bq = 0;
            }
			my @tokens = split(/[ {]/,$line);
            my $end = (tell $fh);			
			my $offset = $end - length $line;            
            $old_hash = { name => $tokens[1], offset => $offset };
            $contig->{reads}{$tokens[1]}{read_position}= $old_hash;
            $contig->{af_start} = $offset;
			for(my $i=1;$i<$contig->{read_count};$i++)
			{
				my $line = <$fh>;
				my @tokens = split(/[ {]/,$line);
            	my $end = (tell $fh);			
				my $offset = $end - length $line;            
            	$old_hash = { name => $tokens[1], offset => $offset };
            	$contig->{reads}{$tokens[1]}{read_position}= $old_hash;				
            }		
			
            $contig->{af_end} = (tell $fh);
            
		}
		elsif($first_three eq "RD ")
		{
			my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - length $line;
			if(!$found_rd)
			{
				$contig->{rd_start} = $offset ;			
            	$found_rd = 1;
			}
			$old_hash = { offset => $offset,
                          name => $tokens[1],
                          read_tags => [],
                          length => length($line)};
                        
                        
            $old_hash->{sequence}{offset} = (tell $fh)+1;
			$fh->seek($tokens[2],1);
			$contig->{reads}{$tokens[1]}{read} = $old_hash;			
			
		}        
		elsif($first_three eq "CO ")
		{
			$contig->{contig_length} = $offset - $contig->{offset};
			$contig->{rd_end} = $offset;
			$fh->seek(- length($line),1);
			last;
		
		}		
		elsif(substr($first_three,0,2) eq "BQ")
        {
            my $offset = (tell $fh) - length $line;
            $contig->{base_qualities}{offset} = $offset; 
            $contig->{base_sequence}{length} = ($offset-1)-$contig->{offset};
			$found_bq = 1;
			$fh->seek($contig->{sequence_length}*2,1);
			
        }
		elsif($first_three eq "WA ")
		{
			my $offset = (tell $fh) - length $line;
            $fh->seek(-length($line),1);
			last;
		}
		elsif($first_three eq "CT{")
		{
			my $offset = (tell $fh) - length $line;
			$fh->seek(-length ($line),1);
			last;
			
		}
		elsif(substr($line,0,3) eq "DS ")
		{
			my $offset = (tell $fh) - length $line;
        	$old_hash->{ds}{offset} = $offset;  
        	$old_hash->{length} = $offset - $old_hash->{offset};							
		}
		elsif(substr($line,0,3) eq "QA ")
		{
        	my $offset = (tell $fh) - length $line;
        	$old_hash->{qa}{offset} = $offset;
        	$old_hash->{sequence}{length} = ($offset - 1) - $old_hash->{sequence}{offset};
		    $old_hash->{length} = $offset - $old_hash->{offset};
        }
		elsif($first_three eq "RT{")
		{
			my $offset = (tell $fh) - length $line;
			my $first_length = length $line;
			$line = <$fh>;
			my @tokens = split(/[ {]/,$line);            
			$old_hash = {offset => $offset, length => (length($line)+ $first_length)};
			push (@{$contig->{reads}{$tokens[0]}{read}{read_tags}} ,$old_hash );	
			
		}		        
        else
        {            
            $old_hash->{length} += length($line) if(defined($old_hash));
        }
	}    
	return $contig;

}

sub _build_empty_contig_index
{
	my ($self, $fh, $line, $file_offset) = @_;
	my %contigs;
	my @assembly_tag_indexes;
    my $old_hash = undef;
    my $contig = undef;
    my $first_bs = 1;
    my $found_bq = 0;
    my $found_qa = 0;
    my $found_af = 0;
    my $found_rd = 0;
	my $co_count = 0;
    $fh->seek($file_offset,0) if defined $file_offset;
	
	#build contig data structures
	my @tokens = split(/[ {]/,$line);
	my $offset = (tell $fh) - length $line;            

	$contig = { offset => $offset,
                  name => $tokens[1],
                      read_count => $tokens[3],
                      base_segments => {line_count => $tokens[4]},#\@base_segments,
                      contig_tags => [] ,
                      contig_loaded => 0 ,
					  contig_indexed => 0,
                      length => length($line),
					  sequence_length => $tokens[2],
                      contig_length => length($line)}; 	            							  
		
	while(my $line = <$fh>)
	{
		my $first_three = substr($line, 0,3);	
		        
		if($first_three eq "CO "||$first_three eq "WA "||$first_three eq "CT{")
		{
			my $offset = (tell $fh) - length $line;
			$contig->{contig_length} = $offset - $contig->{offset};
			$fh->seek(- length($line),1);
			last;		
		}
		
		
	}    
	return $contig;
}

sub _connect
{   
    my ($self) = @_;
	my $handle;
	
	eval { $handle = DBI->connect($self->_db_dsn, $self->{user_name}, $self->{password}); };
	my $try=0;
	while(!defined $handle && ($try<5))
    {
        #print $self->dbh->errstr."\n";
		sleep 30;print STDERR "sleeping for 10 seconds\n";
		eval { $handle = DBI->connect($self->_db_dsn,$self->{user_name},$self->{password}); };
        $try++;
		#$self->_sleep2;
    }
    return if(!defined $handle);
	$self->dbh($handle);
        
    $self->dbh->{LongReadLen} = 800000000;    
}

sub _sleep2
{
    my ($self) = @_;
    sleep($self->{sleep});
    print "Sleeping for ".$self->{sleep}." seconds\n";
    #if($self->{sleep}<60)
    #{
    #    $self->{sleep}++;
    #}

}

sub _sleep
{
    my ($self) = @_;
    #$self->_disconnect;
    sleep($self->{sleep});
    print "Sleeping for ".$self->{sleep}." seconds\n";
    #$self->_connect;
    #if($self->{sleep}<60)
    #{
    #    $self->{sleep}++;
    #}

}

sub get_contig_names
{
    my $self = shift;
    if($self->using_db)
    {
        #$self->_connect;
        my $sth = $self->dbh->prepare(qq{ select name from items where type = "Contig" and asid = $self->{asid} }); 
        while(! defined $sth->execute())
        {
            print $sth->errstr."\n";
            $self->_sleep;
        }
        my @contig_names;
        while (my $temp = $sth->fetchrow_arrayref)
        {
            push @contig_names, $temp->[0]; 
        }
        #$self->_disconnect;
		@contig_names = sort { _cmptemp($a, $b) } @contig_names;
        return \@contig_names;
    }   
    return [sort { _cmptemp($a, $b) } keys %{$self->{contigs}}] ;
}

sub get_contig
{
    my ($self, $contig_name, $load) = @_;
    
    confess "No contig name given.\n" unless defined $contig_name;    
    
    my %contigs = %{ $self->{contigs} };
    my $contig_index;
    my $contig_found = 0;
    if($self->using_db)
    {        
        #$self->_connect;        
        while(! defined $self->sth_get->execute($contig_name))
        {
            print $self->sth_get->errstr."\n";
            $self->_sleep;
        }
        my $ref = $self->sth_get->fetchrow_arrayref;
        if(!defined $ref)
        {
            die "Failed to fetch contig $contig_name\n";
        }
        if(my $temp = $ref->[0] )
        {
			$contig_index = Storable::thaw($temp, );
            $contig_found = 1;
        }
        $self->sth_get->finish;
        #$self->_disconnect;        
    }
    else
    {
        if(exists $contigs{$contig_name})
        {
            $contig_index = $contigs{$contig_name};
            $contig_found = 1;
        }                
    }
    
    confess "Could not get contig for name: $contig_name\n" unless $contig_found;
    if($contig_index->{contig_loaded})
    {          
        #my $contig = Storable::dclone($contig_index->{contig_object});
		my $contig = $contig_index->{contig_object};
        $contig->thaw($self, $self->_input_file, $self->_input);
        return $contig;       
    }
    else 
    {
		if($load)
		{
			return $self->get_contig_old($contig_index);		
		}
		else
		{    
        	my $input = $self->_input;
        	my $reader = $self->_reader;
        	my $contig_callback = Genome::Assembly::Pcap::Sources::Ace::Contig->new(name => $contig_index->{name},
        	index => $contig_index, reader => $self->_reader, fh => $self->_input, file_name => $self->_input_file);    
        	return Genome::Assembly::Pcap::Contig->new(callbacks => $contig_callback);   
    	}
    }
}

sub get_contig_old
{
	my ($self, $contig_index) = @_;    		
    
    my $input = $self->_input;
    my $reader = $self->_reader;
    my $ace_contig;
    my %reads; #contins read_positions and read_tags
    my @base_segments;
    my @contig_tags;
    my $result = $input->seek($contig_index->{offset},0);
    $ace_contig = $reader->next_object;
    #grab reads
    foreach my $read_index (values %{$contig_index->{reads}})
    {
        $input->seek($read_index->{read}{offset},0);
        my $ace_read = $reader->next_object;
        $reads{$ace_read->{name}} = Genome::Assembly::Pcap::Read->new(ace_read => $ace_read);
		#grab read_tags
		foreach my $read_tag_index (@{$read_index->{read}{read_tags}})
		{
			$input->seek($read_tag_index->{offset},0);
			my $read_tag = $self->_build_read_tag($reader->next_object);
			$reads{$read_tag->parent}->add_tag($read_tag);	
		}	
    }
	#grab read_positions
	foreach my $read_position_index (values %{$contig_index->{reads}})
	{
		$input->seek($read_position_index->{read_position}{offset},0);
		my $ace_read_position = $reader->next_object;
		$reads{$ace_read_position->{read_name}}->ace_read_position ($ace_read_position);	
	}	
		
	#grab contig_tags
	foreach my $contig_tag_index (@{$contig_index->{contig_tags}})
	{
		$input->seek($contig_tag_index->{offset},0);
		push @contig_tags, Genome::Assembly::Pcap::TagParser->new()->parse($input);
	}
	#grab base_segments
	$input->seek($contig_index->{base_segments}{offset},0);
	while(my $obj = $reader->next_object)
	{
		last if ($obj->{type} ne "base_segment");
		push @base_segments, $obj;	
	}	
	#glue everything together
    my $contig = Genome::Assembly::Pcap::Contig->new(ace_contig => $ace_contig,
                                                reads => \%reads,
                                                contig_tags => \@contig_tags,
                                                base_segments => \@base_segments);
	
	return $contig;	
}

sub using_db
{
    my ($self, $using_db) = @_;
    
    if(@_>1)
    {
        $self->{using_db} = $using_db;
    }
    return $self->{using_db};
}

sub get_fh
{
	my ($self, $file_name) = @_;
	if(!defined $self->{file_handles}{$file_name})
	{
		$self->{file_handles}{$file_name} = IO::File->new($file_name);
	}
	return $self->{file_handles}{$file_name};
}

sub add_contig
{
	my ($self, $contig) = @_;
	
	my $contig_index;
	my $contig_found = 0;
    $contig->freeze;
	if($self->using_db)
    {
        $contig_index = { offset => -1, contig_loaded => 1, name => $contig->name, contig_object => $contig};
        #$self->_connect;        
        while(! defined $self->sth_set->execute($contig->name, Storable::freeze($contig_index), "Contig", scalar keys %{$contig->reads}))
        {
            print $self->sth_set->errstr."\n";
			#my $tmp = IO::File->new(">/tmp/tmpdump");
			#print $tmp Storable::freeze($contig_index);
			#$tmp->close;
            $self->_sleep;
        }
        while(! defined $self->sth_set->execute("has_changed",0, 0, 1))
        {
            print $self->sth_set->errstr."\n";
            $self->_sleep;
        }
        #$self->_disconnect;      
        
    }
	else
    {
        my %contigs = %{ $self->{contigs} };      
    
        if(exists $contigs{$contig->name})
        {
            $contig_index = $contigs{$contig->name};
            $contig_found = 1;
        }
        if($contig_found)
        {
            $contig_index->{offset} = -1;
            $contig_index->{contig_loaded} = 1;     
            $contig_index->{contig_object} = $contig->copy($contig);        
        }
        else
        {
            $contig_index = { offset => -1, contig_loaded => 1, name => $contig->name, contig_object => $contig->copy($contig) };
            $self->{contigs}{$contig->name} = $contig_index;           
        }                
    }
    $contig->thaw($self,$self->_input_file, $self->_input);
}

sub remove_contig
{
    my ($self, $contig_name) = @_;
    if($self->using_db)
    {
        #$self->_connect;        
        while(! defined $self->sth_rem->execute($contig_name))
        {
            print $self->sth_rem->errstr."\n";      
            $self->_sleep;
        }
        while(! defined $self->sth_set->execute("has_changed",0,0,1))
        {
            print $self->sth_set->errstr."\n";      
            $self->_sleep;
        }
        #$self->_disconnect;        
        return;     
    }
    delete $self->{contigs}{$contig_name} if (exists $self->{contigs}{$contig_name});   
}

sub get_assembly_tags
{
    my ($self) = @_;
    my $input = $self->_input;
    my $reader = $self->_reader;
    if($self->using_db)
    {
        #$self->_connect;        
        while(! defined $self->sth_get->execute("assembly_tags"))
        {
            print $self->sth_get->errstr."\n";      
            $self->_sleep;
        }
		my $temp = $self->sth_get->fetchrow_arrayref->[0];
		$self->{assembly_tags} = Storable::thaw($temp);
        $self->sth_get->finish;
        #$self->_disconnect;
    }
    
    if(!($self->{assembly_tags}{tags_loaded}))
    {
        my @assembly_tags;
        foreach my $assembly_tag_index (@{$self->{assembly_tags}{tag_indexes}})
        {       
            $input->seek($assembly_tag_index->{offset},0);
            my $assembly_tag = $self->_build_assembly_tag($reader->next_object);
            push @assembly_tags, $assembly_tag;
        }
        $self->{assembly_tags}{tags} = \@assembly_tags;
        $self->{assembly_tags}{tags_loaded} = 1; 
    }
    return [ map {$self->_copy_assembly_tag($_)} @{$self->{assembly_tags}{tags}} ]; 
    
}

sub set_assembly_tags
{
    my ($self, $assembly_tags) = @_;    
    $self->{assembly_tags}{tags} = [ map {$self->_copy_assembly_tag($_)} @{$assembly_tags}];
    $self->{assembly_tags}{tags_loaded} = 1;
    if($self->using_db)
    {
        #$self->_connect;        
        while(! defined $self->sth_set->execute("assembly_tags", Storable::freeze($self->{assembly_tags}), "Contig", 0))
        {
            print $self->sth_set->errstr."\n";  
            $self->_sleep;
        }
        while(! defined $self->sth_set->execute("has_changed",0,0,1))
        {
            print $self->sth_set->errstr."\n";  
            $self->_sleep;
        }
        $self->sth_set->finish;
        #$self->_disconnect;
    }
    else
    {
        $self->{assembly_tags}{tags} = [ map {$self->_copy_assembly_tag($_)} @{$assembly_tags}];
        $self->{assembly_tags}{tags_loaded} = 1;    
    }
}

sub write_file
{
    my ($self, %params) = @_;
    #reopen output file
    
    if(exists $params{output})
    {
        $self->_output ( $params{output});              
    }
    elsif(exists $params{output_file})
    {
        $self->_output_file ($params{output_file});
        $self->_output(IO::File->new(">".$self->_output_file));
    }
    elsif(defined $self->_output)
    {
        $self->_output->seek(0,0) or die "Could not seek to beginning of write file\n";     
    }
    else
    {
        die "Could not find find file to write to.\n";
    }
    $self->_writer (Genome::Assembly::Pcap::Ace::Writer->new($self->_output));
    #first, come up with a list of read and contig counts
    my $read_count=0;
    my $contig_count=0;
    my @contig_names;
    my @contigs;
    if($self->using_db)
    {
        #$self->_connect;
        my $sth = $self->dbh->prepare(qq{ select name, count from items where type = "Contig" and asid = $self->{asid}}); 
        while(! defined $sth->execute())
        {
            print $sth->errstr."\n";        
            $self->_sleep;
        }

        while (my $temp = $sth->fetchrow_arrayref)
        {
            push @contig_names, $temp->[0];
            $read_count += $temp->[1]; 
        }       
        
        @contig_names = sort { _cmptemp($a, $b) } @contig_names; #sort { $a =~ /Contig(\d+)/ <=> $b =~ /Contig(\d+)/ }@contig_names;
        
        $contig_count = @contig_names;
        #$self->_disconnect;
    }
    else
    {
        @contigs = sort { $a->{name} =~ /Contig(\d+)/ <=> $b->{name} =~ /Contig(\d+)/ } values %{$self->{contigs}};
        $contig_count = @contigs;
    
        foreach my $contig (@contigs)
        {
            if($contig->{offset} != -1)
            {
                $read_count += scalar keys %{$contig->{reads}}; 
            }
            else
            {
                $contig->{contig_object}->thaw($self,$self->_input_file, $self->_input);
                $read_count += $contig->{contig_object}->read_count;                
            }
        }
    }   
    my $ace_assembly = { type => 'assembly', 
                          contig_count => $contig_count,
                          read_count => $read_count };
    $self->_writer->write_object($ace_assembly);
    #initialize contig tags array
    $self->{contig_tags} = [];
    #write out contigs
    if($self->using_db)
    {
        #$self->_connect;
        foreach my $contig_name (@contig_names)
        {
            
            while(! defined $self->sth_get->execute($contig_name))
            {
                print $self->sth_get->errstr."\n";          
                $self->_sleep;
            }
			my $temp = $self->sth_get->fetchrow_arrayref->[0];
			my $contig_index = Storable::thaw($temp, );
            if($contig_index->{offset} == -1)
            {
                $self->_write_contig_from_object($contig_index->{contig_object});           
            }
            else
            {
                $self->_write_contig_from_file($contig_index);
            }
        }
        $self->sth_get->finish;
        
    }
    else
    {
        foreach my $contig_index (@contigs)
        {
            if($contig_index->{offset} == -1)
            {
                $self->_write_contig_from_object($contig_index->{contig_object});           
            }
            else
            {
                $self->_write_contig_from_file($contig_index);
            }   
        }
    }
    #write out contig tags
    if(defined $self->{contig_tags})
    {
        foreach my $tag (@{$self->{contig_tags}})
        {
            $self->_writer->write_object($tag);     
        }
        $self->{contig_tags} = undef;   
    }
    
    if($self->using_db)
    {        
        while(! defined $self->sth_get->execute("assembly_tags"))
        {
            print $self->sth_get->errstr."\n";      
            $self->_sleep;
        }
        if(my $temp = $self->sth_get->fetchrow_arrayref)
        {
			$self->{assembly_tags}{tags} = Storable::thaw($temp->[0], );
            $self->{assembly_tags}{tags_loaded} = 1;
			while(! defined $self->sth_getcount( $self->dbh->prepare(qq{ select count from items where name = ? and asid = $self->{asid}})))
    		{
        		print $self->dbh->errstr."\n";
        		$self->_sleep2;
    		}
			$self->sth_getcount->execute("assembly_tags");
			if(!$self->sth_getcount->fetchrow_arrayref->[0])
			{
				$self->{assembly_tags}{tags} = [];
			}
			$self->sth_getcount->finish;
        }
        #else
        #{
        #   $self->{assembly_tags} = {assembly_tags => 0, tags => []}
        #}
        $self->sth_get->finish;
        #$self->_disconnect;     
        
    }
    
    #write out assembly tags
    if($self->{assembly_tags}{tags_loaded})
    {
        foreach my $assembly_tag (@{$self->{assembly_tags}{tags}})
        {
            $self->_write_assembly_tag($assembly_tag);
        }   
    }
    else
    {
        foreach my $assembly_tag_index (@{$self->{assembly_tags}{tag_indexes}})
        {
            $self->_input->seek($assembly_tag_index->{offset},0);
            my $assembly_tag = $self->_reader->next_object;
            $self->_write_assembly_tag($assembly_tag);  
        }
    }
    #$self->_output->close; 
    $self->_output->autoflush(1);
}

sub _write_contig_from_object
{
	my ($self, $contig) = @_;
	my $writer = $self->_writer;
    my $output = $self->_output;
	#my %reads = %{$contig->reads}; #contins read_positions and read_tags
	my @contig_tags = @{$contig->{tags}||[]} ;
    my $contig_index = $contig->{callbacks}{index};
    my $input = $self->_input;
	my $input_file = $self->_input_file;
	
    my $reader = $self->_reader;
	$contig->thaw($self, $self->_input_file, $self->_input);
    $DB::single = 1;
	if(!defined $input||(exists $contig->{callbacks}{file_name}&&($input_file ne $contig->{callbacks}{file_name})))
	{
		$input = $contig->{callbacks}{fh};
	}
	$reader->{input} = $input;
	#first write contig	hash
    if($contig->loaded||$contig->check_data_changed("contig")||$contig->check_data_changed("padded_base_string"))
    {
        my @tokens = ("CO",$contig->name,$contig->base_count,$contig->read_count,$contig->base_segment_count,
                      $contig->complemented?"C":"U");
        my $line = join " ",@tokens;
        $line .= "\n";
        print $output $line;
    }
    else
    {
        $input->seek($contig_index->{offset},0);
        my $string = <$input>;
        print $output $string;    
    }
    #next, write contig sequence
    if($contig->loaded||$contig->check_data_changed("padded_base_string"))
    {
        my $consensus = $contig->padded_base_string;
		$writer->_write_sequence($output, $consensus);
    }
    else
    {
        my $consensus;
        $input->seek($contig_index->{offset},0); 
        my $line = <$input>;
        my $length = $contig_index->{base_sequence}{length} - length($line);
        $input->read($consensus, $length);
        print $output $consensus;
        
    }
	if($contig->loaded||$contig->check_data_changed("padded_base_quality"))
    {
        print $output "\n\nBQ";

        my $width = 50;#$self->width();
        my @bq = @{$contig->unpadded_base_quality};
        for (my $i = 0; $i < @bq; $i += 1) {
            if ($i % $width == 0) {
                print $output "\n";
            }
            print $output " $bq[$i]";
        }
        print $output "\n\n";
    }
    else
    {
		print $output "\n\n";
        my $string;
        $input->seek($contig_index->{base_qualities}{offset},0);
        $input->read($string, $contig_index->{base_qualities}{length});
        print $output $string;      
    }
	my @reads;
    if($contig->loaded||$contig->check_data_loaded("children"))
    {
        #if it's been loaded, we need to check each read to see if it's changed
        #yeah, I know, this is kind of slow, I'll add a better callback mechanism in 
        #the future
        my $children = $contig->children;
		#@reads = sort { $a->position <=> $b->position } values %{$children};
        foreach my $read (values %{$children})
        {
            if($contig->loaded||$read->check_data_changed("self"))
            {
                if($contig->loaded||$read->check_data_changed("read_position"))
                {
                    print $output "AF ".$read->name;
                    if($read->complemented)
                    {
                        print $output " C ".$read->position."\n";
                    }
                    else
                    {
                        print $output " U ".$read->position."\n";
                    }                
                }
                else
                {
                   $input->seek($contig_index->{reads}{$read->name}{read_position}{offset},0);
                   my $line = <$input>;
                   print $output $line;                
                }            
            }
            else
            {
                $input->seek($contig_index->{reads}{$read->name}{read_position}{offset},0);
                my $line = <$input>;
                print $output $line;            
            }        
        }    
    }
    else
    {
        #my %reads = %{$contig_index->{reads}};
        #foreach my $read (values %{reads})
        #{            
        #        $input->seek($contig_index->{reads}{$read->name}{read_position}{offset},0);
        #        my $line = <$input>;
        #        print $output $line;                  
        #}
        my $string;
        $input->seek($contig_index->{af_start},0);
        $input->read($string,$contig_index->{af_end}-$contig_index->{af_start});
        print $output $string;
    }
    if($contig->loaded||$contig->check_data_changed("base_segments"))
    {	
		my @base_segments = @{$contig->base_segments};
        foreach my $base_segment (@base_segments)
        {
            $writer->write_object($base_segment);
        } 
		print $output "\n";       
    }
    else
    {
        my $string;
        $input->seek($contig_index->{base_segments}{offset},0);
        $input->read($string, $contig_index->{base_segments}{length});
        print $output $string;    
    }
    if($contig->loaded||$contig->check_data_loaded("children"))
    {
        #if it's been loaded, we need to check each read to see if it's changed
        #yeah, I know, this is kind of slow, I'll add a better callback mechanism in 
        #the future
        my $children = $contig->children;
        foreach my $read (values %{$children})
        {
            if($contig->loaded||$read->check_data_changed("self"))
            {
                if($contig->loaded||$read->check_data_changed("read"))
                {
                    my @tokens = ("RD",$read->name,$read->length,$read->info_count,scalar @{$read->tags});
                    my $string = join " ",@tokens,"\n";
                    print $output $string;
                
                }
                else
                {
                    my $string;
                    $input->seek($contig_index->{reads}{$read->name}{read}{offset},0);
                    $string = <$input>;;
                    print $output $string;                
                }
                
                if($contig->loaded||$read->check_data_changed("padded_base_string"))
                {
                    my $sequence = $read->padded_base_string;
                    my $seq_len = length($sequence);
                    my $width = 50;
                    for (my $i = 0;$i < $seq_len; $i += $width ) {
                        print $output substr($sequence, $i, $i + ($width-1) < $seq_len ? $width : $seq_len - $i) . "\n";
                    }
                    print $output "\n";                
                }
                else
                {
                    my $string;
                    $input->seek($contig_index->{reads}{$read->name}{read}{sequence}{offset},0);
                    $input->read($string, $contig_index->{reads}{$read->name}{read}{sequence}{length});
                    print $output $string; 
					print $output "\n";               
                }
                if($contig->loaded||$read->check_data_changed("qa"))
                {
                    print $output ("QA ", $read->qual_clip_start, " ",$read->qual_clip_end, " ", $read->align_clip_start, " ", $read->align_clip_end,"\n");                
                }
                else
                {
                    $input->seek($contig_index->{reads}{$read->name}{read}{qa}{offset},0);
                    my $string = <$input>;
                    print $output $string;                
                }
                if($contig->loaded||$read->check_data_changed("ds"))
                {
                    print $output ("DS CHROMAT_FILE: ",$read->chromat_file," PHD_FILE: ",$read->phd_file,
                    " CHEM: ", $read->chemistry, " TIME: ", $read->time); 
					print $output " DYE: ", $read->dye if ($read->dye);
					print $output "\n\n";               
                }
                else
                {
                    $input->seek($contig_index->{reads}{$read->name}{read}{ds}{offset},0);
                    my $string = <$input>;
                    print $output $string;
					print $output "\n";                
                }            
            }
			else #check if data has changed
			{
				my $string;
				$input->seek($contig_index->{reads}{$read->name}{read}{offset},0);
				$input->read($string, $contig_index->{reads}{$read->name}{read}{length});
				print $output $string;

			}        
        }    
    }
    else
    {
        my $string;
        $input->seek($contig_index->{rd_start},0);
        $input->read($string,$contig_index->{rd_end}-$contig_index->{rd_start});
        print $output $string;
        #my %reads = %{$contig_index->{reads}};
        #foreach my $read (values %{reads})
        #{            
        #        my $string;
        #        $input->seek($contig_index->{reads}{$read->{name}}{read}{offset},0);
        #        $input->read($string, $contig_index->{reads}{$read->name}{read}{length});
        #       print $output $string;                  
        #}    
    }
    if($contig->loaded||$contig->check_data_changed("tags"))
    {
        #store contig tags for writing, also convert
        #tag to low level format for writing
        my @contig_tags = @{$contig->tags};
        foreach my $tag (@contig_tags)
        {
            #$self->_write_contig_tag($contig_tag);
            my $contig_tag =  {
                type => 'contig_tag',
                tag_type => $tag->type,
                date => $tag->date,
                program => $tag->source,
                contig_name => $tag->parent,
                scope => 'ACE',
                start_pos => $tag->start,
                end_pos => $tag->stop,
                data => $tag->text,
                no_trans => $tag->no_trans,
            };
            push @{$self->{contig_tags}}, $contig_tag;
        }    
    }
    else
    {
        my @contig_tags_index = @{$contig_index->{contig_tags}};         
          
        #write out contig tags
        foreach my $contig_tag_index (@contig_tags_index)
        {
            $input->seek($contig_tag_index->{offset},0);
            push @{$self->{contig_tags}},
            map
            {
            {
                type => 'contig_tag',
                tag_type => $_->type,
                date => $_->date,
                program => $_->source,
                contig_name => $_->parent,
                scope => 'ACE',
                start_pos => $_->start,
                end_pos => $_->stop,
                data => $_->text,
                no_trans => $_->no_trans,
            }
                }       
            Genome::Assembly::Pcap::TagParser->new()->parse($input);
        }    
    }
}

sub _write_contig_from_file
{
	my ($self, $contig_index) = @_;
	my $input = $self->_input;
    my $output = $self->_output;
	my $writer = $self->_writer;
	my $reader = $self->_reader;
	my @contig_tags_index = @{$contig_index->{contig_tags}};
	
	if(exists $contig_index->{fh})
	{
		$input = $contig_index->{fh};
		$reader = $contig_index->{reader};
	}   
    #write out contig
    my $contig_string;
    $input->seek($contig_index->{offset},0);
    $input->read($contig_string, $contig_index->{contig_length});
    print $output $contig_string;	
	#write out contig tags
	foreach my $contig_tag_index (@contig_tags_index)
	{
	    $input->seek($contig_tag_index->{offset},0);
	    push @{$self->{contig_tags}},
	    map
	    {
		{
		    type => 'contig_tag',
		    tag_type => $_->type,
		    date => $_->date,
		    program => $_->source,
		    contig_name => $_->parent,
		    scope => 'ACE',
		    start_pos => $_->start,
		    end_pos => $_->stop,
		    data => $_->text,
		    no_trans => $_->no_trans,
		}
            }		
	    Genome::Assembly::Pcap::TagParser->new()->parse($input);
	}
}

sub _write_index_to_file
{
    my ($self, $file_name) = @_;
    
    my $hindex = {};
    $hindex->{contigs} = $self->{contigs};
    $hindex->{assembly_tags} = $self->{assembly_tags};
    
    store $hindex, $file_name;
    return;   
    
}

sub _load_index_from_file
{
    my ($self, $file_name) = @_;
    
    my $hindex = retrieve $file_name;
    
    $self->{contigs} = $hindex->{contigs};
    $self->{assembly_tags} = $hindex->{assembly_tags};
    return;    
    
}

sub _build_assembly_tag {
    my ($self, $obj) = @_;

    my $tag = new Genome::Assembly::Pcap::Tag(
        type => $obj->{tag_type},
        date => $obj->{date},
        source => $obj->{program},
        text => $obj->{data},
    );
    return $tag;
}

sub _build_read_tag {
    my ($self, $obj) = @_;
    my $tag = new Genome::Assembly::Pcap::Tag(
        type => $obj->{tag_type},
        date => $obj->{date},
        source => $obj->{program},
        parent => $obj->{read_name},
        scope => 'ACE',
        start => $obj->{start_pos},
        stop => $obj->{end_pos},
    );
    return $tag;
}

sub _copy_assembly_tag
{
	my ($self, $assembly_tag) = @_;
	return Storable::dclone($assembly_tag);
}

sub _write_assembly_tag
{
    my ($self, $tag) = @_;

	
	my $ace_tag = { type => 'assembly_tag',
					tag_type => $tag->type,
					program => $tag->source,
					date => $tag->date,
					data => $tag->text,
				  };
    
	$self->_writer->write_object($ace_tag);    
        
    return;
}

sub _write_read_tag
{
    my ($self, $tag) = @_;
		
	my $read_tag =  {
		type => 'read_tag',
        tag_type => $tag->type,
        date => $tag->date,
        program => $tag->source,
        read_name => $tag->parent,
        scope => 'ACE',
        start_pos => $tag->start,
        end_pos => $tag->stop,
    };    
    
    $self->_writer->write_object($read_tag);
    return;
}

sub _write_contig_tag
{
    my ($self, $tag) = @_;

    my $contig_tag =  {
		type => 'contig_tag',
        tag_type => $tag->type,
        date => $tag->date,
        program => $tag->source,
        contig_name => $tag->parent,
        scope => 'ACE',
        start_pos => $tag->start,
        end_pos => $tag->stop,
		data => $tag->text,
		no_trans => $tag->no_trans,
    };
	
	$self->_writer->write_object($contig_tag);   	

    return;
}

sub get_read_order
{
	my ($self, $contig) = @_;
	my @contigs = @{ $self->{contigs} };
	my $contig_index;
	my $contig_found = 0;
	
    foreach my $temp_contig_index (@contigs)
	{
		if ($temp_contig_index->{name} eq $contig->name)
		{
            $contig_index = $temp_contig_index;
			$contig_found = 1;
			last;	
		}
	}	
	
	return [map {$_->{name}} @{$contig_index->{reads}}];
}   

sub has_changed
{
    my ($self) = @_;
    #$self->_connect;    
    while(! defined $self->sth_getcount->execute("has_changed"))
    {
        print $self->sth_getcount->errstr."\n"; 
        $self->_sleep;
    }
    my $temp = $self->sth_getcount->fetchrow_arrayref;
    $self->sth_getcount->finish;    
    #$self->_disconnect;
    return $temp->[0] if defined $temp;
    return 0;
}
sub _disconnect
{
    my ($self) = @_;
    #while(! defined $self->dbh->begin_work)
    #{
    #   print $self->dbh->errstr."\n";
    #   $self->_sleep2;
    #}
    #while(! defined $self->sth_get->execute(""))
    #{
    #   print $self->sth_get->errstr."\n";
    #   $self->_sleep2;
    #}
    #while(! defined $self->sth_getcount->execute(""))
    #{
    #   print $self->sth_getcount->errstr."\n";     
    #   $self->_sleep2;
    #}
    #while(! defined $self->sth_set->execute("","",""))
    #{
    #   print $self->sth_set->errstr."\n";      
    #   $self->_sleep2;
    #}
    #while(! defined $self->sth_rem->execute(""))
    #{
    #   print $self->sth_rem->errstr."\n";      
    #   $self->_sleep2;
    #}
    #while(! defined $self->dbh->commit)
    #{
    #   print $self->dbh->errstr."\n";
    #   $self->_sleep2;
    #}      
    #$self->sth_get->finish; 
    #$self->sth_getcount->finish; 
    #$self->sth_set->finish; 
    #$self->sth_rem->finish;
    $self->sth_create (undef);



    $self->sth_get( undef );
    $self->sth_getcount( undef );
    $self->sth_set( undef );
    $self->sth_rem( undef );
    $self->dbh->disconnect;
    $self->dbh(undef);


}

sub get_num
{
    my ($name) = @_;
    my ($ctg_num) = $name =~ /Contig(\d+)\.\d+/;
	($ctg_num) = $name =~ /Contig(\d+)/ if(!defined $ctg_num);
	($ctg_num) = $name =~ /.?(\d+)/ if(!defined $ctg_num);
	
    return $ctg_num;
}

sub get_ext
{
    my ($name) = @_;
    my ($ctg_ext) = $name =~ /Contig\d+\.(\d+)/;
    return $ctg_ext;
}

sub _cmptemp
{
    my ($a, $b) = @_;
    my $num1 = get_num($a);
    my $num2 = get_num($b);
    if($num1 > $num2)
    {
        return 1;
    }elsif($num2 > $num1)
    {
        return -1;
    }
    my $ext1 = get_ext($a);$ext1 = 0 if(!defined $ext1);
    my $ext2 = get_ext($b);$ext2 = 0 if(!defined $ext2);
    if($ext1 > $ext2)
    {
        return 1;
    }elsif($ext2 > $ext1)
    {
        return -1;
    }
    return 0;
    
}



sub DESTROY 
{
    my ($self) = @_;
    if($self->using_db)
    {
        $self->_disconnect;
    }
}

1;

=pod

=head1 NAME

Ace - Object oriented ace file reader/writer

=head1 SYNOPSIS

my $ace_object = Genome::Assembly::Pcap::Ace->new(input_file => "inputfilename", output_file => "outputfilename", using_db => 1, input_file_index => "inputfileindex");

 my @contig_names = $ace_object->get_contig_names();
 my $contig = $ace_object->get_contig("Contig0.1");
 $ace_object->remove_contig("Contig0.1");

 $ace_object->write_file;
    
=head1 DESCRIPTION

Genome::Assembly::Pcap::Ace indexes an ace file, and allows the user to get Contig objects from the ace file, edit them, and write the file back to the hard disk when finished.

=head1 METHODS

=head1 new 

my $ace_object = new Genome::Assembly::Pcap::Ace(input_file => $input_file, output_file => $output_file);

input_file - required, the name of the input ace file.

output_file - option, the name of output ace file.  You can give ace_object the file handle when you create it, or later when you write it.  If you are reading, then you don't need to specify the file handle.

using_db - optional, lets ace ojbect know whether it should store cached data on the file system or keep it in memory for fast access.

load_index_from_file - optional, tells Ace to load the index from the file, and the user is required to specify the index file name.

=head1  get_contig_names 

my @contig_names = $ace_object->get_contig_names();

returns a list of contig names in the ace file.

=head1 get_contig 

my $contig = $ace_object->get_contig("Contig0.1");
    
returns a Bio::ContigUtilites::Contig object to the user.

=head1 add_contig 

 my $contig = $ace_object->get_contig("Contig0.1");
 ...
 $ace_object->add_contig($contig);
    
inserts a contig into the ace file.  If a contig with that name already exists, then it is overwritten by the data in the newly added contig.

=head1 remove_contig 

$ace_object->remove_contig("Contig0.1");
    
returns a Contig from the ace file.

=head1 get_assembly_tags 

my @assembly_tags = $ace_object->get_assembly_tags;
    
returns an array off assembly tags to the user.

=head1 set_assembly_tags 

$ace_object->set_assembly_tags(\@assembly_tags);
    
replaces the current array of assembly tags in the ace file with a new list of assembly tags.

=head1 write_file

$ace_object->write_file;
    
This function will write the ace object in it's current state to the output ace file specified during object construction.

=head1 Author(s)

 Jon Schindler <jschindl@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
