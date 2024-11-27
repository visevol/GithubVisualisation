import React, { useState } from "react";
import "assets/styles/addRepository.scss";
import { Input } from "antd";
import { useNavigate } from "react-router-dom";

import { searchOrCreateRepository } from "api";

const AddRepository: React.FC = () => {
  const [url, setUrl] = useState<string>("");
  const navigate = useNavigate();

  const handleEnterPress = async () => {
    const repository = await searchOrCreateRepository(url);

    if (repository == null) {
      alert(`The repository does not exists. Make sure the url points to a public repository on Github.`)
    } else {
      navigate(`/repository/${repository.id}/change-volume`);
    }
  };

  return (
    <div className="cscope">
      <h1 className="cscope__title">CScope</h1>
      <p className="cscope__subtitle">Insert repository URL</p>
      <div className="cscope__search">
        <Input
          className="cscope__input"
          value={url}
          placeholder="Insert URL and press enter"
          onPressEnter={handleEnterPress}
          onChange={e => setUrl(e.target.value)}
        />
      </div>
    </div>
  );
};

export default AddRepository;
