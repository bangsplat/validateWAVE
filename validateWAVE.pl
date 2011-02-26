#!/usr/bin/perl
use strict;	# Enforce some good programming rules

#####
#
#	validateWAVE.pl
#	version:	1.0
#	created:	2011-02-25
#	modified:	2011-02-25
#	author:		Theron Trowbridge
#
#	description:
#		validate WAVE file file by checking RIFF format and WAVE header
#	
#	syntax:
#		validateWAVE.pl <input.wav>
#
#		accepts glob arguments (i.e., "rewrapWav.pl *.wav")
#
#	output:
#		outputs any issues to stdio (can be piped to file)
#	
#####


# variables/constants

my ( $input_file, $basename, $output_file, $extension );
my ( $result, $header, $buffer );
my ( $chunk_id, $chunk_size, $format );
my ( $sub_chunk_id, $sub_chunk_size );
my ( $sub_chunk_1_id, $sub_chunk_1_size, $audio_format );
my ( $num_channels, $sample_rate, $byte_rate, $block_align, $bits_per_sample );
my ( $sub_chunk_2_id, $sub_chunk_2_size );
my ( $file_size, $file_error, $bytes_read );
my ( $total_output_file_size, $output_file_chunk_size );
my ( $errors, $warnings, $done );
my ( $fmt_chunks_found, $data_chunks_found );
my ( $bytes_per_sample, $bytes_per_sample_frame );


# subroutines

#	short_value()
#	convert argument into little-endian unsigned short
sub short_value {
	return( unpack( "S<", $_[0] ) );
}

#	long_value()
#	convert argument into little-endian unsigned long
sub long_value {
	return( unpack( "L<", $_[0] ) );
}

# find_chunk( $find_chunk_id )
# find specified RIFF chunk in the INPUT_FILE
# returns the size of the chunk data (as per the header)
# leaves file positioned at first byte of chunk data
sub find_chunk {
	my ( $result, $buffer, $result, $read_chunk_id, $read_chunk_size );
	my $find_chunk_id = $_[0];
	my $done = 0;
		
	seek( INPUT_FILE, 12, 0 );			# skip past the end of the header
		
	while ( !$done ) {
		$result = read ( INPUT_FILE, $buffer, 8 );
		if ( $result eq 0 ) {			# end of file
			seek ( INPUT_FILE, 0, 0 );	# rewind file
			return( 0 );			# return 0, which will indicate an error
		}
		
		$read_chunk_id = substr( $buffer, 0, 4 );
		$read_chunk_size = long_value( substr( $buffer, 4, 4 ) );
		
		if ( $read_chunk_id eq $find_chunk_id ) { return( $read_chunk_size ); }	# return chunk size
		else { seek( INPUT_FILE, $read_chunk_size, 1 ); }			# seek to next chunk		
	}
}


# main

# If no arguments passed, return usage string
if ( !$ARGV[0] ) { print "Usage: validateWAVE.pl <filename>\n"; }

# Otherwise, parse through each argument passed and try to convert it
FILE: foreach $input_file (@ARGV) {
	# set error/warning flags
	$errors = $warnings = 0;
	
	# check file name (is extension .wav?)
	$input_file =~ /\.([^\.]+)$/;
	$extension = $1;
	if ( $extension ne "wav" ) {
		print "$input_file: warning: file name extension is not .wav\n";
		$warnings++;
	}
	
	# open the file
	$result = open( INPUT_FILE, "<", $input_file );
	if ( $result eq undef ) {
		print "$input_file: error: could not open file $!\n";
		$errors++;
		print "$input_file: aborting with $errors errors and $warnings warnings\n";
		next FILE;
	}
	
	binmode( INPUT_FILE );			# binary file
	$file_size = -s INPUT_FILE;		# get size of input file
	
	# read RIFF header
	$result = read( INPUT_FILE, $header, 12 );
	if ( $result == undef ) {
		print "$input_file: error: could not read RIFF header $!\n";
		$errors++;
		print "$input_file: aborting with $errors errors and $warnings warnings\n";
		close( INPUT_FILE );
		next FILE;
	}
	
	# analyze RIFF header
	$chunk_id = substr( $header, 0, 4 );
	$chunk_size = long_value( substr( $header, 4, 4 ) );
	$format = substr( $header, 8, 4 );
	
	# ChunkID should be "RIFF"
	if ( $chunk_id ne "RIFF" ) {
		print "$input_file: error: not a RIFF file\n";
		$errors++;
		print "$input_file: aborting with $errors errors and $warnings warnings\n";
		close( INPUT_FILE );
		next FILE;
	}
	
	# ChunkSize + 8 should equal the total file size
	if ( ( $chunk_size + 8 ) ne $file_size ) {
		print "$input_file: warning: ChunkSize is not correct\n";
		$warnings++;
	}
	
	# Format should be "WAVE"
	if ( $format ne "WAVE" ) {
		print "$input_file: error: not a WAVE file\n";
		$errors++;
		print "$input_file: aborting with $errors errors and $warnings warnings\n";
		close( INPUT_FILE );
		next FILE;
	}
	
	# parse through RIFF chunks in the file
	$done = 0;
	
	# reset fmt/data chunk counters
	$fmt_chunks_found = $data_chunks_found = 0;
	
	while ( !$done ) {
		
		# read next chunk header
		$result = read( INPUT_FILE, $buffer, 8 );
		
		# if we read 0 bytes, files ended gracefully
		if ( $result eq 0 ) {
			print "$input_file: info: end of file\n";
			$done = 1;
		} elsif ( $result eq 8 ) {
			# parse the chunk header
			$sub_chunk_id = substr( $buffer, 0, 4 );
			$sub_chunk_size = long_value( substr( $buffer, 4, 4 ) );
			
			# report chunk type/size
			print "$input_file: info: $sub_chunk_id chunk found ($sub_chunk_size+8 bytes)\n";
			
			# check for standard chunk types
			if ( $sub_chunk_id eq "fmt " ) {
				$fmt_chunks_found++;
			} elsif ( $sub_chunk_id eq "data" ) {
				$data_chunks_found++;
			} else {
				print "$input_file: info: $sub_chunk_id is not a standard WAVE chunk\n";
			}
			
			# skip ahead sub_chunk_size bytes
			seek( INPUT_FILE, $sub_chunk_size, 1 );
		} else {	# if we read anything other than 0 or 8, unexpected EOF
			print "$input_file: error: unexpected end of file\n";
			$errors++;
			print "$input_file: aborting with $errors errors and $warnings warnings\n";
			close( INPUT_FILE );
			next FILE;
		}
	}
	
	# if we get to this point, file is a valid RIFF file
	# now we need to see if it is a valid WAVE file
		
	# make sure we had one (only) each of data and fmt chunks
	if ( $fmt_chunks_found eq 0 ) {
		print "$input_file: error: no WAVE header (fmt chunk) found\n";
		$errors++;
	}
	if ( $fmt_chunks_found gt 1 ) {
		print "$input_file: warning: more than one WAVE header (fmt chunk) found\n";
		$warnings++;
	}
	
	# go find the WAVE header and make sure it is OK
	if ( $fmt_chunks_found eq 1 ) {
		$sub_chunk_1_id = "fmt ";
		$sub_chunk_1_size = find_chunk( $sub_chunk_1_id );
		
		# fmt chunk (including header) should be 24 bytes long
		# without header, that's 16 bytes
		if ( $sub_chunk_1_size lt 16 ) {
			print "$input_file: error: WAVE header is too short\n";
			$errors++;
			print "$input_file: aborting with $errors errors and $warnings warnings\n";
			close( INPUT_FILE );
			next FILE;
		}
		if ( $sub_chunk_1_size gt 16 ) {
			print "$input_file: warning: WAVE header is larger ($sub_chunk_1_size bytes) than normal (16 bytes)\n";
			$warnings++;
		}
		
		# parse WAVE header
		$result = read( INPUT_FILE, $header, $sub_chunk_1_size );

		if ( $result eq undef ) {
			print "$input_file: error reading WAVE header\n";
			$errors++;
			print "$input_file: aborting with $errors errors and $warnings warnings\n";
			close( INPUT_FILE );
			next FILE;
		}
		# read WAVE header values
		$audio_format = short_value( substr( $header, 0, 2 ) );
		$num_channels = short_value( substr( $header, 2, 2 ) );
		$sample_rate = long_value( substr( $header, 4, 4 ) );
		$byte_rate = long_value( substr( $header, 8, 4 ) );
		$block_align = short_value( substr( $header, 12, 2 ) );
		$bits_per_sample = short_value( substr( $header, 14, 2 ) );
		
		# report value of each header field
		
		# audio format should be 1
		# if not, it indicates that audio is not PCM
		if ( $audio_format eq 1 ) {
			print "$input_file: info: audio format is 1 (PCM)\n";
		} else {
			print "$input_file: warning: audio format should be 1 - audio is not PCM?\n";
			$warnings++;
		}
		
		# number of channels
		print "$input_file: info: number of channels is $num_channels\n";
		if ( $num_channels lt 1 ) {
			print "$input_file: error: there must be at least one audio channel\n";
			$errors++;
		}
		
		# sampling rate
		print "$input_file: info: sampling rate is $sample_rate\n";
		if ( $sample_rate lt 1 ) {
			print "$input_file: error: sampling rate must be positive\n";
			$errors++;
		}
		
		# byte rate
		print "$input_file: info: byte rate is $byte_rate\n";
		# byte_rate should equal sample_rate * block_align
		if ( $byte_rate ne ( $sample_rate * $block_align ) ) {
			print "$input_file: error: byte rate value is wrong\n";
			$errors++;
		}
		
		# block align
		print "$input_file: info: block align is $block_align\n";
		# block_align should be
		# 	num_channels * ( bits_per_sample div 8 )
		# 	rounded up to next whole number
		$bytes_per_sample = int($bits_per_sample / 8);	# div - ignores remainder
		if ( ( $bits_per_sample % 8 ) ne 0 ) { $bytes_per_sample++; }	# add 1 if any remainder
		$bytes_per_sample_frame = $bytes_per_sample * $num_channels;
		if ( $bytes_per_sample_frame ne $block_align ) {
			print "$input_file: error: block align value is wrong - should be $bytes_per_sample_frame\n";
			$errors++;
		}
		
		# bit depth
		print "$input_file: info: bits per sample: $bits_per_sample\n";
		if ( $bits_per_sample lt 1 ) {
			print "$input_file: error: bits per sample must be positive value\n";
			$errors++;
		}
	}
		
	if ( $data_chunks_found eq 0 ) {
		print "$input_file: error: no WAVE data chunk found\n";
		$errors++;
	}
	if ( $data_chunks_found gt 1 ) {
		print "$input_file: warning: more than one WAVE data chunk found\n";
		$warnings++;
	}
		
	# finish up
	print "$input_file: finished with $errors errors and $warnings warnings\n";
	close( INPUT_FILE );
}
