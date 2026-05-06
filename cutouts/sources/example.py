import itertools
from collections import defaultdict

from fornax_cutouts.models.base import Positions
from fornax_cutouts.models.cutouts import FilenameLookupResponse, FilenameWithMetadata
from fornax_cutouts.sources import (
    AbstractMissionSource,
    MissionMetadata,
    cutout_registry,
)


@cutout_registry.register_source()
class ExampleSource(AbstractMissionSource):
    """
    Example source for Fornax Cutouts.
    """

    metadata: MissionMetadata = MissionMetadata(
        name="example",
        pixel_size=0.25,  # in arcseconds
        max_cutout_size=6000,  # in pixels
        filter=["example_filter1", "example_filter2"],
        survey=["example_dr1", "example_dr2"],
        # You can add any additional query parameters or metadata here
        example_parameter=["value1", "value2"],
    )

    def __init__(self):
        pass

    def validate_request(self, size: int, **request):
        is_valid = super().validate_request(size=size, **request)
        # Any additional validation logic can be added here
        is_valid &= self._validate_list_parameter(
            request.get("example_parameter"), self.metadata.example_parameter
        )
        return is_valid

    def get_filenames(
        self,
        position: Positions,
        filter: list[str] = ["example_filter1", "example_filter2"],
        survey: list[str] = ["example_dr2"],
        example_parameter: list[str] = ["value1"],
    ) -> list[FilenameLookupResponse]:
        """
        Get the filenames for the given position, filter, survey, and example parameter.
        """
        template_fname = "{survey}/example_filename_{ra_bin}_{dec_bin}_{filter}_{example_parameter}.fits"

        target_results = defaultdict(list)

        for pos, surv, filt, ep in itertools.product(
            position, survey, filter, example_parameter
        ):
            ra_bin = int(pos.ra // 90) * 90
            dec_bin = int((pos.dec + 90) // 45) * 45 - 90
            fname = template_fname.format(
                survey=surv,
                ra_bin=ra_bin,
                dec_bin=dec_bin,
                filter=filt,
                example_parameter=ep,
            )
            target_results[pos].append(
                FilenameWithMetadata(
                    filename=fname,
                    metadata={
                        "survey": surv,
                        "filter": filt,
                        "example_parameter": ep,
                        "example_metadata": "abc.xyz",
                    },
                )
            )

        results = [
            FilenameLookupResponse(
                mission=self.metadata.name, target=pos, filenames=filenames
            )
            for pos, filenames in target_results.items()
        ]

        return results
