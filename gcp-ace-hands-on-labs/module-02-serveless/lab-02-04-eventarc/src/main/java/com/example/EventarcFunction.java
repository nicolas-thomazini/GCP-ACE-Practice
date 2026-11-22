
package com.example;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.cloud.functions.CloudEventsFunction;
import io.cloudevents.CloudEvent;

import java.util.logging.Logger;

public class EventarcFunction implements CloudEventsFunction {

    private static final Logger logger =
            Logger.getLogger(EventarcFunction.class.getName());

    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void accept(CloudEvent event) throws Exception {

        logger.info("Eventarc event received!");

        String eventId = event.getId();
        String eventType = event.getType();
        String eventSource = event.getSource().toString();

        logger.info("Event ID: " + eventId);
        logger.info("Event Type: " + eventType);
        logger.info("Event Source: " + eventSource);

        JsonNode data = objectMapper.readTree(
                event.getData().toBytes()
        );

        String bucket = data.path("bucket").asText();
        String fileName = data.path("name").asText();
        String generation = data.path("generation").asText();

        logger.info("New file received!");
        logger.info("Bucket: " + bucket);
        logger.info("File: " + fileName);
        logger.info("Generation: " + generation);
    }
}
