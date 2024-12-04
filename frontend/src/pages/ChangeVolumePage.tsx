import React, { useEffect, useState } from "react";
import { useDataSettingContext } from "../context/DataSettingContext";
import "assets/styles/changeVolume.scss";
import DateAndFileInput from "components/DateAndFileInput";
import BuddleGraphMetrics from "components/BubbleGraphMetrix";
import { MetricsProps } from "models/MetricsProps";
import SliderFilterMetrix from "components/SliderFilterMetrix";
import { FileFolderCommits } from "models/FileFolderCommits";
import BubbleGraphDisplay from "components/BubbleGraphDisplay";
import { useParams } from "react-router-dom";
import { getFileOverTime } from "api";
import { SliderFilterCodeLine } from "models/SliderFilterCodeLine";

const ChangeVolumePage: React.FC = () => {
  const {
    repository,
    repositoryId,
    setRepositoryId,
    startDate,
    endDate,
    filePath,
  } = useDataSettingContext();
  const [filterAddLineMetrics, setFilterAddLineMetrics] =
    useState<SliderFilterCodeLine>({
      codeLines: 1000,
      maxCodeLine: 1000,
    });

  const [filterDeleteLineMetrics, setFilterDeleteLineMetrics] =
    useState<SliderFilterCodeLine>({
      codeLines: 1000,
      maxCodeLine: 1000,
    });
  const [fileFolderDatas, setFileFolderDatas] = useState<FileFolderCommits[]>(
    []
  );

  const bubbleMetrix: MetricsProps = {
    commitCount: 140,
    codeSize: 1055,
    mainAuthor: "Boblebri Codeur",
    modifiedDate: "1 month ago",
  };

  const { id } = useParams<{ id: string }>();

  useEffect(() => {
    if (!repositoryId) {
      setRepositoryId(Number(id));
    }
  }, [id]);

  useEffect(() => {
    if (repository) {
      const fetchData = async () => {
        const data: FileFolderCommits[] = await getFileOverTime(
          repository.id,
          startDate,
          endDate
        );
        const maxAdditionsLines = Math.max(
          ...data.map((item) => item.total_additions)
        );
        const maxDeletionsLines = Math.max(
          ...data.map((item) => item.total_deletions)
        );
        setFilterAddLineMetrics({
          codeLines: maxAdditionsLines,
          maxCodeLine: maxAdditionsLines,
        });
        setFilterDeleteLineMetrics({
          codeLines: maxDeletionsLines,
          maxCodeLine: maxDeletionsLines,
        });

        const newPathFilterData = data.filter((item: FileFolderCommits) => {
          return filePath === "" || item.path === filePath;
        });
        setFileFolderDatas(newPathFilterData);
      };

      fetchData();
    }
  }, [repository, startDate, endDate, filePath]);

  return (
    <div className="two-side-structure">
      <div className="page">
        <BubbleGraphDisplay
          filterAddLineMetrics={filterAddLineMetrics}
          filterDeleteLineMetrics={filterDeleteLineMetrics}
          fileFolderDatas={fileFolderDatas}
        />
      </div>
      <div>
        <DateAndFileInput />
        <SliderFilterMetrix
          filterAddLineMetrics={filterAddLineMetrics}
          setFilterAddLineMetrics={setFilterAddLineMetrics}
          filterDeleteLineMetrics={filterDeleteLineMetrics}
          setFilterDeleteLineMetrics={setFilterDeleteLineMetrics}
        />
        <BuddleGraphMetrics metricsProps={bubbleMetrix} />
      </div>
    </div>
  );
};

export default ChangeVolumePage;
