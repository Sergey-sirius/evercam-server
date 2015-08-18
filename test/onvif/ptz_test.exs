defmodule PTZTest do
  use ExUnit.Case
  alias EvercamMedia.ONVIFPTZ
  
  test "get_nodes method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.get_nodes("149.13.244.32", "8100", "admin", "mehcam")
    result_map = Poison.Parser.parse!(response)
    assert  result_map 
            |> Map.get("PTZNode")
            |> Map.get("Name") == "PTZNODE"
    
    assert result_map 
           |> Map.get("PTZNode")
           |> Map.get("token") == "PTZNODETOKEN"
   end 

  test "get_configurations method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.get_configurations("149.13.244.32", "8100", "admin", "mehcam")
    result_map = Poison.Parser.parse!(response)
    assert result_map
           |> Map.get("PTZConfiguration")
           |> Map.get("Name") == "PTZ"
    assert result_map
           |> Map.get("PTZConfiguration")
           |> Map.get("NodeToken") == "PTZNODETOKEN"
  end 

  test "get_presets method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.get_presets("149.13.244.32", "8100", "admin", "mehcam", "Profile_1")
    [first_preset | _] = 
      Poison.Parser.parse!(response)
      |> Map.get("Presets")
    assert first_preset 
           |> Map.get("Name") == "Back Main Yard"
    assert first_preset
           |> Map.get("token") == "1"
  end   

  test "goto_preset method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.goto_preset("149.13.244.32", "8100", "admin", "mehcam", "Profile_1", "6")
    assert response == "{}"
  end   
  
  test "stop method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.stop("149.13.244.32", "8100", "admin", "mehcam", "Profile_1")
    assert response == "{}"
  end

  test "pan_tilt coordinates available" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [x: 0.5671, y: 0.9919]
    assert String.contains? response, "PanTilt"
    assert not String.contains? response, "Zoom"
  end

  test "pan_tilt coordinates and zoom available" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [x: 0.5671, y: 0.9919, zoom: 1.0]
    assert String.contains? response, "Zoom"
    assert String.contains? response, "PanTilt" 
  end

  test "pan_tilt coordinates available broken but zoom ok" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [x: 0.5671, zoom: 0.9919]
    assert String.contains? response, "Zoom"
    assert not String.contains? response, "PanTilt"
  end

  test "pan_tilt_zoom only zoom available" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [zoom: 0.5671]
    assert String.contains? response, "Zoom"
    assert not String.contains? response, "PanTilt"
  end

  test "pan_tilt_zoom empty" do
    response = ONVIFPTZ.pan_tilt_zoom_vector []
    assert not String.contains? response, "Zoom"
    assert not String.contains? response, "PanTilt" 
  end

end

