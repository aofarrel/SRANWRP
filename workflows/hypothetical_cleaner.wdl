version 1.0

workflow taskless_fill_in_nulls {
	input {
		String entity_id
		String? some_metadata_value
	}
	String fallback = "UNDEFINED"

	output {
		String cleaned = select_first([some_metadata_value, fallback])
	}

}

