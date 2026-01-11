using DotPulsar;
using DotPulsar.Extensions;


var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

const string myTopic = "persistent://public/default/mytopic";

// connecting to pulsar://localhost:6650
await using var client = PulsarClient.Builder().Build();

// produce a message
await using var producer = client.NewProducer(Schema.String).Topic(myTopic).Create();
await producer.Send("Hello World");

// consume messages
await using var consumer = client.NewConsumer(Schema.String)
    .SubscriptionName("MySubscription")
    .Topic(myTopic)
    .InitialPosition(SubscriptionInitialPosition.Earliest)
    .Create();

await foreach (var message in consumer.Messages())
{
    Console.WriteLine($"Received: {message.Value()}");
    await consumer.Acknowledge(message);
}




void setup()
{
    var clientCertificate = new X509Certificate2("admin.pfx");
    var client = PulsarClient.Builder()
        .AuthenticateUsingClientCertificate(clientCertificate)
        .Build();


client, err := pulsar.NewClient(ClientOptions{
    URL: "pulsar+ssl://broker.example.com:6651/",
    TLSTrustCertsFilePath: "/path/to/ca.cert.pem",
    Authentication: pulsar.NewAuthenticationTLS("/path/to/client.cert.pem", "/path/to/client.key-pk8.pem"),
})
}