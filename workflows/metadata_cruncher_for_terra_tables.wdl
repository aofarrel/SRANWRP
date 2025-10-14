version 1.0

import "../tasks/processing_tasks.wdl" as processingtasks

workflow Metadata_Cruncher {
	input {
		Array[String] entity_ids = ["foo", "bar", "bizz", "buzz"]
		String        a_metadata_key = "breed"
		Array[String] a_metadata_values = ["West Highland White Terrier", "Doodle", "orange cat", "idk I found him at a gas station"]
		String        b_metadata_key = "age"
		Array[Int]    b_metadata_values = [3, 4, 5, 6]
	}

	call processingtasks.strings_to_csv {
		input:
			entity_ids = entity_ids,
			a_metadata_key = a_metadata_key,
			a_metadata_values = a_metadata_values,
			b_metadata_key = b_metadata_key,
			b_metadata_values = b_metadata_values
	}
}