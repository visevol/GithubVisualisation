import React, { useEffect } from "react";
import { useDataSettingContext } from "../context/DataSettingContext";
import "assets/styles/developersInput.scss";
import DateAndFileInput from "components/DateAndFileInput";
import { useParams } from "react-router-dom";

const DevelopersInputPage: React.FC = () => {
  const { repositoryId, setRepositoryId } = useDataSettingContext();

  const { id } = useParams<{ id: string }>();

  useEffect(() => {
    if (!repositoryId) {
      setRepositoryId(Number(id));
    }
  }, [id]);

  return (
    <div className="two-side-structure">
      <div className="page">
        <div className="visualization-placeholder">[Coming soon...]</div>
      </div>
      <DateAndFileInput />
    </div>
  );
};

export default DevelopersInputPage;
